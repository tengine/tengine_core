# -*- coding: utf-8 -*-
require 'tengine/event'
require 'tengine/mq'
require 'eventmachine'
require 'selectable_attr'

class Tengine::Core::Kernel
  include ::SelectableAttr::Base
  include Tengine::Core::KernelRuntime

  attr_reader :config, :status
  attr_accessor :before_delegate, :after_delegate

  def initialize(config)
    @status = :initialized
    @config = config
    @processing_event = false
  end

  def start(&block)
    update_status(:starting)
    bind
    if config[:tengined][:wait_activation]
      update_status(:waiting_activation)
      wait_for_activation(&block)
    else
      activate(&block)
    end
  end

  def stop(force = false)
    if self.status == :running
      update_status(:shutting_down)
      EM.cancel_timer(@heartbeat_timer) if @heartbeat_timer
      if mq.queue.default_consumer
        mq.queue.unsubscribe
        close_if_shutting_down if !@processing_event || force
      end
    else
      update_status(:shutting_down)
      # wait_for_actiontion中の処理を停止させる必要がある
    end
    update_status(:terminated)
  end

  def dsl_context
    unless @dsl_context
      @dsl_context = Tengine::Core::DslContext.new(self)
      @dsl_context.config = config
    end
    @dsl_context
  end
  alias_method :context, :dsl_context

  def bind
    dsl_context.__evaluate__
    Tengine::Core::stdout_logger.debug("Hanlder bindings:\n" << dsl_context.to_a.inspect)
    Tengine::Core::HandlerPath.default_driver_version = config.dsl_version
  end

  def wait_for_activation(&block)
    activated = false
    activation_file_name = "#{config[:tengined][:activation_dir]}\/tengined_#{Process.pid}.activation"
    start_time = Time.now
    while((Time.now - start_time).to_i <= config[:tengined][:activation_timeout].to_i) do
      if File.exist?(activation_file_name)
        # ファイルが見つかった
        activated = true
        break
      end
      sleep 1
    end
    if activated
      File.delete(activation_file_name)
      # activate開始
      activate(&block)
    else
      update_status(:shutting_down)
      raise Tengine::Core::ActivationTimeoutError, "activation file found timeout error."
    end
  end

  def activate
    EM.run do
      # queueへの接続までできたら稼働中
      # self.status_key = :running if mq.queue
      update_status(:running) if mq.queue
      subscribe_queue
      enable_heartbeat if config.heartbeat_enabled?
      yield(mq) if block_given? # このyieldは接続テストのための処理をTengine::Core:Bootstrapが定義するのに使われます。
    end
  end

  # subscribe to messages in the queue
  def subscribe_queue
    mq.queue.subscribe(:ack => true, :nowait => true) do |headers, msg|
      process_message(headers, msg)
    end
  end

  def process_message(headers, msg)
    safety_processing_event(headers) do
      raw_event = parse_event(msg)
      if raw_event.nil?
        headers.ack
        return
      end

      event = save_event(raw_event)
      unless event
        headers.ack
        return
      end

      ack_policy = ack_policy_for(event)
      safety_processing_headers(headers, event, ack_policy) do
        ack if ack_policy == :at_first
        handlers = find_handlers(event)
        safty_handlers(handlers) do
          delegate(event, handlers)
          ack if all_submitted?
        end
      end
      close_if_shutting_down
    end
  end

  GR_HEARTBEAT_EVENT_TYPE_NAME = "gr_heart_beat.tengined".freeze
  GR_HEARTBEAT_ATTRIBUTES = {
    :level => Tengine::Event::LEVELS_INV[:debug]
  }.freeze

  def enable_heartbeat
    EM.defer do
      @heartbeat_timer = EM.add_periodic_timer(config.heartbeat_period) do
        Tengine::Core.stdout_logger.debug("sending heartbeat") if config[:verbose]
        sender.fire(GR_HEARTBEAT_EVENT_TYPE_NAME, GR_HEARTBEAT_ATTRIBUTES.dup)
      end
    end
  end

  private

  def parse_event(msg)
    begin
      raw_event = Tengine::Event.parse(msg)
      Tengine.logger.debug("received a event #{raw_event.inspect}")
      return raw_event
    rescue Exception => e
      Tengine.logger.error("failed to parse a message because of [#{e.class.name}] #{e.message}.\n#{msg}")
      return nil
    end
  end

  def fire_failed_event(raw_event)
    EM.next_tick do
      Tengine.logger.debug("sending #{raw_event.event_type_name}failed.tengined event.") if config[:verbose]
      event_attributes = {
        :level => Tengine::Event::LEVELS_INV[:error],
        :properties => { :original_event => raw_event }
      }
      sender.fire("#{raw_event.event_type_name}.failed.tengined", event_attributes)
    end
  end

  # 受信したイベントを登録
  def save_event(raw_event)
    event = Tengine::Core::Event.create!(
      raw_event.attributes.update(:confirmed => (raw_event.level <= config.confirmation_threshold)))
    Tengine.logger.debug("saved a event #{event.inspect}")
    event
  rescue Mongo::OperationFailure => e
    Tengine.logger.warn("same key's event has already stored. \n[#{e.class.name}] #{e.message}")
    # Model.exists?だと上手くいかない時があるのでModel.whereを使っています
    # fire_failed_event(raw_event) if Tengine::Core::Event.exists?(confitions: { key: raw_event.key, sender_name: raw_event.sender_name })
    fire_failed_event(raw_event) if Tengine::Core::Event.where(:key => raw_event.key, :sender_name => raw_event.sender_name).count > 0
    return nil
  rescue Exception => e
    Tengine.logger.error("failed to save a event #{event.inspect}\n[#{e.class.name}] #{e.message}")
    raise e
  end

  # イベントハンドラの取得
  def find_handlers(event)
    handlers = Tengine::Core::HandlerPath.find_handlers(event.event_type_name)
    Tengine.logger.debug("handlers found: " << handlers.map{|h| "#{h.driver.name} #{h.id.to_s}"}.join(", "))
    handlers
  end

  def delegate(event, handlers)
    before_delegate.call if before_delegate.respond_to?(:call)
    handlers.each do |handler|
      safety_handler(handler) do
        block = dsl_context.__block_for__(handler)
        begin
          handler.process_event(event, &block)
        rescue Exception => e
          Tengine.logger.debug("[#{e.class.name}] #{e.message}\n  " << e.backtrace.join("\n  "))
          dsl_context.fire("#{event.event_type_name}.error.tengined",
            :properties => {
              :original_event => event.to_json,
              :error_class_name => e.class.name,
              :error_message => e.message,
              :error_backtrace => e.backtrace,
              :block_source_location => '%s:%d' % block.source_location,
            })
        end
      end
    end
    after_delegate.call if after_delegate.respond_to?(:call)
  end

  def close_if_shutting_down
    # unsubscribed されている場合は安全な停止を行う
    # return if mq.queue.default_consumer
    return unless status == :shutting_down
    # TODO: loggerへ
    # puts "connection closing..."
    mq.connection.close{ EM.stop_event_loop }
  end

  STATUS_LIST = [
    :initialized,        # 初期化済み
    :starting,           # 起動中
    :waiting_activation, # 稼働要求待ち
    :running,            # 稼働中
    :shutting_down,      # 停止中
    :terminated,         # 停止済
  ].freeze

  # TODO 状態遷移図、状態遷移表に基づいたチェックを入れるべき
  # https://cacoo.com/diagrams/hwYJGxDuumYsmFzP#EBF87
  def update_status(status)
    raise ArgumentError, "Unkown status #{status.inspect}" unless STATUS_LIST.include?(status)
    @status_filepath ||= File.expand_path("tengined_#{Process.pid}.status", config.status_dir)
    @status = status
    File.open(@status_filepath, "w"){|f| f.write(status.to_s)}
  end

  def sender
    @sender ||= Tengine::Event::Sender.new(mq)
  end

  def mq
    @mq ||= Tengine::Mq::Suite.new(config[:event_queue])
  end

  # 自動でログ出力する
  extend Tengine::Core::MethodTraceable
  method_trace(:start, :stop, :bind, :wait_for_activation, :activate, :subscribe_queue, :update_status,
    :process_message, :parse_event, :fire_failed_event, :save_event, :find_handlers, :delegate, :close_if_shutting_down,
    :enable_heartbeat)
end


class Tengine::Core::ActivationTimeoutError < StandardError
end

