# -*- coding: utf-8 -*-
require 'tengine/event'

class Tengine::Core::Handler
  include Mongoid::Document
  field :filepath, :type => String
  field :lineno, :type => Integer
  field :event_type_names, :type => Array
  array_text_accessor :event_type_names
  field :filter, :type => Hash, :default => {}
  map_yaml_accessor :filter

  embedded_in :driver, :class_name => "Tengine::Core::Driver"

  def update_handler_path
    event_type_names.each do |event_type_name|
      Tengine::Core::HandlerPath.create!(:event_type_name => event_type_name,
        :driver => self.driver, :handler_id => self.id)
    end
  end

  def process_event(event, &block)
    matched = match?(event)
    Tengine.logger.debug("match?(...) => #{matched} #{block.source_location.inspect}")
    if matched
      # TODO: ログ出力する
      # logger.info("id:#{self.id} handler matches the event key:#{event.key}")
      # puts("id:#{self.id} handler matches the event key:#{event.key}")
      # ハンドラの実行
      @caller = eval("self", block.binding)
      # TODO: ログ出力する
      # logger.info("id:#{self.id} handler executed own block, source:#{block.source_location}")
      # puts("id:#{self.id} handler execute own block, source:#{block.source_location}")
      begin
        @caller.__safety_driver__(self.driver) do
          @caller.__safety_event__(event) do

    Tengine.logger.debug("@__event__: #{@__event__.inspect}")

            @caller.instance_eval(&block)
          end
        end
      rescue Exception => e
        Tengine.logger.error("exception occurred in #{block.source_location.inspect} [#{e.class.name}] #{e.message}.")
      end
    end
  end

  def fire(event_type_name)
    @caller.fire(event_type_name)
  end

  def match?(event)
    filter.blank? ? true : Visitor.new(filter, event, driver.session).visit
  end

  # HashとArrayで入れ子になったfilterのツリーをルートから各Leafの方向に辿っていくVisitorです。
  # 正確にはVisitorパターンではないのですが、似ているのでメタファとしてVisitorとしました。
  class Visitor
    def initialize(filter, event, session)
      @filter = filter
      @event = event
      @session = session
      @current = @filter
    end

    def visit
      Tengine.logger.debug("visiting #{@current.inspect}")
      send(@current['method'])
    end

    def backup_current(node)
      backup = @current
      @current = node
      begin
        return yield
      ensure
        @current = backup
      end
    end

    def and
      children = @current["children"]
      # children.all?{|child| backup_current(child){ visit }} # これだと全てのchildrenについて評価せずfalseがあったら処理を抜けてしまいます。
      children.map{|child| backup_current(child){ visit }}.all?
    end

    def find_or_mark_in_session
      name = @current['pattern'].to_s
      key = "mark_#{name}"
      if name == @event.event_type_name
        unless @session.system_properties[key]
          @session.system_properties.update(key => true)
          @session.save!
          Tengine.logger.debug("system_properties.updated #{@session.system_properties.inspect}")
        end
        return true
      else
        return @session.system_properties[key]
      end
    end

  end


end
