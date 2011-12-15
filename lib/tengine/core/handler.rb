# -*- coding: utf-8 -*-
require 'tengine/core'

require 'tengine/event'

# イベントハンドラ
#
# Tengineコアは、イベントを受信するとそのイベント種別名にマッチするイベントハンドラを探して
# 見つかったイベントハンドラをすべて実行します。
class Tengine::Core::Handler
  include Mongoid::Document
  include Mongoid::Timestamps
  include Tengine::Core::CollectionAccessible
  include Tengine::Core::SelectableAttr

  # @attribute 実行するRubyのブロックが定義されているファイル名
  field :filepath, :type => String

  # @attribute 実行するRubyのブロックが定義されているファイルでの行番号
  field :lineno  , :type => Integer

  # @attribute 処理するイベントのイベント種別名の配列
  field :event_type_names, :type => Array
  array_text_accessor :event_type_names

  # @attribute イベントが対象かどうかを判断するためのフィルタ定義
  field :filter, :type => Hash, :default => {}
  map_yaml_accessor :filter

  # @attribute 実行対象の取得方法
  field :target_instantiation_cd, :type => String, :default => '01'

  selectable_attr :target_instantiation_cd do
    entry '01', :binding        , "binding"
    entry '02', :static         , "static"
    entry '03', :instance_method, "instance_method"
  end

  # @attribute 実行対象となるメソッドの名前
  field :target_method_name, :type => String


  validates :filepath, :presence => true
  validates :lineno  , :presence => true

  embedded_in :driver, :class_name => "Tengine::Core::Driver"

  def update_handler_path
    event_type_names.each do |event_type_name|
      Tengine::Core::HandlerPath.create!(:event_type_name => event_type_name,
        :driver_id => self.driver.id, :handler_id => self.id)
    end
  end

#   def process_event(event, &block)
#     @caller = eval("self", block.binding)
#     matched = match?(event)
#     if matched
#       # ハンドラの実行
#       @caller.__safety_driver__(self.driver) do
#         @caller.__safety_event__(event) do
#           @caller.instance_eval(&block)
#         end
#       end
#     end
#   ensure
#     @caller = nil
#   end

  def process_event(event)
    case self.target_instantiation_key
    when :instance_method then
      klass = driver.target_class_name.constantize
      inst = klass.new
      m = inst.method(target_method_name)
      m.arity == 0 ? m.call : m.call(event)
    when :static then
      klass = driver.target_class_name.constantize
      m = klass.method(target_method_name)
      m.arity == 0 ? m.call : m.call(event)
    when :binding then
      # do nothing
    else
      raise Tengine::Core::KernelError, "Unsupported target_instantiation_key: #{self.target_instantiation_key.inspect}"
    end
  end

  def fire(event_type_name)
    @caller.fire(event_type_name)
  end

  def match?(event)
    result = filter.blank? ? true : Visitor.new(filter, event, driver.session).visit
    Tengine.logger.debug("match?(#{event.event_type_name.inspect}) => #{result.inspect}")
    result
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

    def match_source_name?
      pattern = @current['pattern']
      @event.source_name.include?(pattern)
    end

  end


end
