# -*- coding: utf-8 -*-
require 'tengine/core'

require 'tengine/event'
require 'tengine/mq'
require 'eventmachine'
require 'selectable_attr'

class Tengine::Core::Kernel
  include ::SelectableAttr::Base
  include Tengine::Core::KernelRuntime
  include Tengine::Core::EventExceptionReportable

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
    cb = proc do |*|
      EM.cancel_timer(@heartbeat_timer) if @heartbeat_timer
      send_last_event do
        close_if_shutting_down
      end
    end
    if self.status == :running
      update_status(:shutting_down)
      if mq.queue.default_consumer
        mq.queue.unsubscribe :nowait => false, &cb
      else
        cb.call
      end
    else
      update_status(:shutting_down)
      # wait_for_actiontion中の処理を停止させる必要がある
    end
    update_status(:terminated)
  end

  def self.top
    @top ||= eval("self", TOPLEVEL_BINDING)
  end

  def dsl_context
    unless @dsl_context
      top = self.class.top
      top.singleton_class.module_eval do
        include Tengine::Core::DslLoader
      end
      top.__kernel__ = self
      top.config = config
      @dsl_context = top
    end
    @dsl_context
  end
  alias_method :context, :dsl_context

  def evaluate
    dsl_context.__evaluate__
  end


  def bind
    # dsl_context.__evaluate__
    # Tengine::Core::stdout_logger.debug("Hanlder bindings:\n" << dsl_context.to_a.inspect)
    # Tengine::Core::HandlerPath.default_driver_version = config.dsl_version
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
      setup_mq_connection
      # queueへの接続までできたら稼働中
      # self.status_key = :running if mq.queue
      update_status(:running) if mq.queue
      subscribe_queue
      enable_heartbeat
      yield(mq) if block_given? # このyieldは接続テストのための処理をTengine::Core:Bootstrapが定義するのに使われます。
      em_setup_blocks.each{|block| block.call }
    end
  end

  # subscribe to messages in the queue
  def subscribe_queue
    mq.queue.subscribe(:ack => true, :nowait => false, :confirm => proc {|*| @initial_connection = true }) do |headers, msg|
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
      if raw_event.key.blank?
        Tengine.logger.warn("invalid event which has blank key: #{raw_event.inspect}")
        headers.ack
        return
      end

      # ハートビートは *保存より前に* 特別扱いが必要
      event = case raw_event.event_type_name
              when /finished\.process\.([^.]+)\.tengine$/
                save_heartbeat_ok(raw_event)
              when /expired\.([^.]+)\.heartbeat\.tengine$/
                save_heartbeat_ng(raw_event)
              when /heartbeat\.tengine$/ # when の順番に注意
                save_heartbeat_beat(raw_event)
              when /(alert|stop)\.execution\.job\.tengine$/
                save_scheduling_event(raw_event)
              when /\.failed\.tengined$/
                save_failed_event(raw_event)
              else
                save_event(raw_event)
              end
      unless event
        headers.ack
        return
      end
      event.kernel = self

      ack_policy = ack_policy_for(event)
      safety_processing_headers(headers, event, ack_policy) do
        ack if ack_policy == :at_first
        handlers = find_handlers(event)
        safty_handlers(handlers) do
          delegate(event, handlers)
          headers.ack if all_submitted?
        end
      end
      close_if_shutting_down
    end
  end

  require 'uuid'
  HEARTBEAT_EVENT_TYPE_NAME = "core.heartbeat.tengine".freeze
  HEARTBEAT_ATTRIBUTES = {
    :key => UUID.new.generate,
    :level => Tengine::Event::LEVELS_INV[:debug],
    :source_name => sprintf("process:%s/%d", ENV["MM_SERVER_NAME"], Process.pid),
    :sender_name => sprintf("process:%s/%d", ENV["MM_SERVER_NAME"], Process.pid),
    :retry_count => 0,
  }.freeze

  def enable_heartbeat
    n = config[:heartbeat][:core][:interval].to_i
    if n and n > 0
      EM.defer do
        @heartbeat_timer = EM.add_periodic_timer(n) do
          Tengine::Core.stdout_logger.debug("sending heartbeat") if config[:verbose]
          sender.fire(HEARTBEAT_EVENT_TYPE_NAME, HEARTBEAT_ATTRIBUTES.dup) do
            @initial_connection = true
          end
        end
      end
    end
  end

  def sender
    unless @sender
      @sender = Tengine::Event::Sender.new(mq)
      @sender.default_keep_connection = true
    end
    @sender
  end

  def mq
    @mq ||= Tengine::Mq::Suite.new(config[:event_queue])
  end

  private

  def setup_mq_connection
    @initial_connection = false
    mq.add_hook :'connection.on_tcp_connection_failure' do |set|
      raise "It seems MQ broker is missing (misconfiguration?)." unless @initial_connection
      case @status when :terminated, :shutting_down then
        raise "Could not properly shut down; MQ broker is missing."
        # EM.stop
      end
    end
    
    # see http://rdoc.info/github/ruby-amqp/amqp/master/file/docs/ErrorHandling.textile#Recovering_from_network_connection_failures
    # mq.connection raiases AMQP::TCPConnectionFailed unless connects to MQ.
    mq.add_hook :'connection.on_error' do |conn, connection_close|
      Tengine::Core.stderr_logger.error("mq.connection.on_error connection_close: " << connection_close.inspect)
    end
    mq.add_hook :'connection.on_tcp_connection_loss' do |conn, settings|
      Tengine::Core.stderr_logger.warn("mq.connection.on_tcp_connection_loss: now reconnecting #{mq.auto_reconnect_delay} second(s) later.")
    end
    mq.add_hook :'connection.after_recovery' do |session, settings|
      Tengine::Core.stderr_logger.info("mq.connection.after_recovery: recovered successfully.")
    end
    # on_open, on_closedに渡されたブロックは、何度再接続をしても最初の一度だけしか呼び出されないが、
    # after_recovery(on_recovery)に渡されたブロックは、再接続の度に呼び出されます。
    # connection.on_open{ Tengine::Core.stderr_logger.info "mq.connection.on_open first time" }
    # connection.on_closed{ Tengine::Core.stderr_logger.info  "mq.connection.on_closed first time" }

    mq.add_hook :'channel.on_error' do |ch, channel_close|
      Tengine::Core.stderr_logger.error("mq.channel.on_error channel_close: " << channel_close.inspect)
      # raise channel_close.reply_text
      # channel_close.reuse # channel.on_error時にどのように振る舞うべき?
    end

    mq.add_hook :'channel.after_recovery' do |ch|
      ch.prefetch(1) do
        Tengine::Core.stderr_logger.info("mq.channel.qos OK")
      end
    end

    # debug
    mq.add_hook :'everything' do |mid, argv|
      Tengine::Core.stdout_logger.debug("EventMachine state changed: #{mid}")
    end
  end

  def parse_event(msg)
    begin
      raw_event = Tengine::Event.parse(msg)
      Tengine.logger.debug("received an event #{raw_event.inspect}")
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

  def save_failed_event(raw_event)
    # これに失敗したときにさらに failed_event を fire してしまうと無限
    # に fire が続いてしまうので NG.
    event = Tengine::Core::Event.create!(
      raw_event.attributes.update(:confirmed => (raw_event.level.to_i <= config.confirmation_threshold)))
    Tengine.logger.debug("saved an event #{event.inspect}")
    event
  rescue Mongo::OperationFailure => e
    Tengine.logger.error("failed to save an event #{raw_event.inspect}\n[#{e.class.name}] #{e.message}")
    # FIXME!!
    # このままではログに埋もれてしまうのでなんとかすべき。
    # 案1 : root@にメールを投げる
    # 案2 : プロセスが死ぬ
    # 案3 : ...
    return nil
  rescue Exception => e
    Tengine.logger.error("failed to save an event #{raw_event.inspect}\n[#{e.class.name}] #{e.message}")
    raise e
  end

  # 受信したイベントを登録
  def save_event(raw_event)
    event = Tengine::Core::Event.create!(
      raw_event.attributes.update(:confirmed => (raw_event.level.to_i <= config.confirmation_threshold)))
    Tengine.logger.debug("saved an event #{event.inspect}")
    event
  rescue Mongo::OperationFailure => e
    Tengine.logger.warn("same key's event has already stored. \n[#{e.class.name}] #{e.message}")
    # Model.exists?だと上手くいかない時があるのでModel.whereを使っています
    # fire_failed_event(raw_event) if Tengine::Core::Event.exists?(confitions: { key: raw_event.key, sender_name: raw_event.sender_name })
    fire_failed_event(raw_event) if Tengine::Core::Event.where(:key => raw_event.key, :sender_name => raw_event.sender_name).count > 0
    return nil
  rescue Exception => e
    Tengine.logger.error("failed to save an event #{event.inspect}\n[#{e.class.name}] #{e.message}")
    raise e
  end

  def upsert(ev, idx)
    ev.collection.driver.update(idx, { "$set" => ev.to_hash }, upsert: true, safe: true, multiple: true)
  end

  def save_scheduling_event(raw_event)
    event = Tengine::Core::Event.new(
      raw_event.attributes.update(:confirmed => (raw_event.level.to_i <= config.confirmation_threshold)))
    hash = upsert(event, source_name: event.source_name, event_type_name: event.event_type_name)
    Tengine.logger.debug("saved an event #{event.inspect}")
    event unless hash["updatedExisting"]
  rescue Mongo::OperationFailure => e
    Tengine.logger.warn("something went wrong. \n[#{e.class.name}] #{e.message}")
    fire_failed_event(raw_event)
    return nil
  rescue Exception => e
    Tengine.logger.error("failed to save an event #{event.inspect}\n[#{e.class.name}] #{e.message}")
    raise e
  end

  def save_heartbeat_beat(raw_event)
    event = Tengine::Core::Event.new(
      raw_event.attributes.update(:confirmed => (raw_event.level.to_i <= config.confirmation_threshold)))
    hash = upsert(event, key: event.key, event_type_name: event.event_type_name)
    Tengine.logger.debug("saved an event #{event.inspect}")
    event unless hash["updatedExisting"]
  rescue Mongo::OperationFailure => e
    Tengine.logger.warn("something went wrong. \n[#{e.class.name}] #{e.message}")
    fire_failed_event(raw_event)
    return nil
  rescue Exception => e
    Tengine.logger.error("failed to save an event #{event.inspect}\n[#{e.class.name}] #{e.message}")
    raise e
  end

  def save_heartbeat_ng(raw_event)
    k = case raw_event.event_type_name when /^expired\.(.+?)\.heartbeat\.tengine$/ then
          ["#$1.heartbeat.tengine", "finished.process.#$1.tengine"]
        else
          raise "unknown event #{raw_event.inspect}"
        end
    event = Tengine::Core::Event.new(
      raw_event.attributes.update(:confirmed => (raw_event.level.to_i <= config.confirmation_threshold)))
    hash = upsert(event, key: event.key, event_type_name: { :"$in" => k })
    Tengine.logger.debug("saved an event #{event.inspect}")
    event if hash["updatedExisting"]
  rescue Mongo::OperationFailure => e
    Tengine.logger.warn("something went wrong. \n[#{e.class.name}] #{e.message}")
    fire_failed_event(raw_event)
    return nil
  rescue Exception => e
    Tengine.logger.error("failed to save an event #{event.inspect}\n[#{e.class.name}] #{e.message}")
    raise e
  end

  def save_heartbeat_ok(raw_event)
    k = case raw_event.event_type_name when /^finished\.process\.(.+?)\.tengine$/ then
          "#$1.heartbeat.tengine"
        else
          raise "unknown event #{raw_event.inspect}"
        end
    event = Tengine::Core::Event.new(
      raw_event.attributes.update(:confirmed => (raw_event.level.to_i <= config.confirmation_threshold)))
    hash = upsert(event, key: event.key, event_type_name: k)
    Tengine.logger.debug("saved an event #{event.inspect}")
    event if hash["updatedExisting"]
  rescue Mongo::OperationFailure => e
    Tengine.logger.warn("something went wrong. \n[#{e.class.name}] #{e.message}")
    fire_failed_event(raw_event)
    return nil
  rescue Exception => e
    Tengine.logger.error("failed to save an event #{event.inspect}\n[#{e.class.name}] #{e.message}")
    raise e
  end

  # イベントハンドラの取得
  def find_handlers(event)
    handlers = Tengine::Core::HandlerPath.find_handlers(event.event_type_name)
    Tengine.logger.debug("handlers found for #{event.event_type_name.inspect}: " << handlers.map{|h| "#{h.driver.name} #{h.id.to_s}"}.join(", "))
    handlers
  end

  def delegate(event, handlers)
    before_delegate.call if before_delegate.respond_to?(:call)
    handlers.each do |handler|
      safety_handler(handler) do
        # block = dsl_context.__block_for__(handler)
        report_on_exception(dsl_context, event) do
          # handler.process_event(event, &block)
          if handler.match?(event)
            handler.process_event(event)
          end
        end
      end
    end
    after_delegate.call if after_delegate.respond_to?(:call)
  end

  def close_if_shutting_down
    # unsubscribed されている場合は安全な停止を行う
    # return if mq.queue.default_consumer
    case status when :shutting_down, :terminated then
      Tengine::Core.stdout_logger.warn("connection closing...")
      mq.stop
    end
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
    Tengine::Core.stdout_logger.info("#{self.class.name}#update_status #{@status.inspect} ==================> #{status.inspect}")
    raise ArgumentError, "Unkown status #{status.inspect}" unless STATUS_LIST.include?(status)
    @status_filepath ||= File.expand_path("tengined_#{Process.pid}.status", config.status_dir)
    @status = status
    File.open(@status_filepath, "w"){|f| f.write(status.to_s)}
  rescue Exception => e
    Tengine::Core.stderr_logger.error("#{self.class.name}#update_status failure. [#{e.class.name}] #{e.message}\n  " << e.backtrace.join("\n  "))
    raise e
  end

  def send_last_event
    argh = HEARTBEAT_ATTRIBUTES.dup
    argh[:level] = Tengine::Event::LEVELS_INV[:info]
    argh.delete :retry_count # use default
    sender.fire "finished.process.core.tengine", argh do
      # 他のデーモンと違ってfinishedをfireしたからといってsender.stopし
      # てよいとは限らない(裏でまだイベント処理中かも)
      yield
    end
  end

  # 自動でログ出力する
  extend Tengine::Core::MethodTraceable
  method_trace(:start, :stop, :bind, :wait_for_activation, :activate,
    :setup_mq_connection, :subscribe_queue, # :update_status, # update_statusは別途ログ出力します
    :process_message, :parse_event, :fire_failed_event, :save_event,
    :find_handlers, :delegate, :close_if_shutting_down, :enable_heartbeat
    )
end


class Tengine::Core::ActivationTimeoutError < StandardError
end

