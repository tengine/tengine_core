# -*- coding: utf-8 -*-
require 'tengine/core'

require 'tengine/event'

class Tengine::Core::Handler
  include Mongoid::Document
  field :filepath, :type => String
  field :lineno  , :type => Integer
  field :event_type_names, :type => Array
  array_text_accessor :event_type_names
  field :filter, :type => Hash, :default => {}
  map_yaml_accessor :filter

  validates :filepath, :presence => true
  validates :lineno  , :presence => true

  embedded_in :driver, :class_name => "Tengine::Core::Driver"

  def update_handler_path
    event_type_names.each do |event_type_name|
      Tengine::Core::HandlerPath.create!(:event_type_name => event_type_name,
        :driver => self.driver, :handler_id => self.id)
    end
  end

  def process_event(event, &block)
    @caller = eval("self", block.binding)
    matched = match?(event)
    Tengine.logger.debug("match?(...) => #{matched} #{block.source_location.inspect}")
    if matched
      # ハンドラの実行
      @caller.__safety_driver__(self.driver) do
        @caller.__safety_event__(event) do
          @caller.instance_eval(&block)
        end
      end
    end
  ensure
    @caller = nil
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
      @session = Tengine::Core::SessionWrapper.new(session)
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
          @session.system_update(key => true)
          Tengine.logger.debug("session.system_updated #{@session.system_properties.inspect}")
        end
        return true
      else
        return @session.system_properties[key]
      end
    end

  end


end
