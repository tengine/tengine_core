# -*- coding: utf-8 -*-
require 'tengine/core'
require 'active_support/core_ext/kernel/singleton_class'

# イベントドライバ定義モジュール
#
module Tengine::Core::Driveable
  extend ActiveSupport::Concern

  included do
    @__context__ = self.singleton_class
    @__context__.extend(ClassMethods)
    @__context__.instance_eval do
      def driver; @driver; end
      def driver=(val); @driver = val; end

      def __on_args__; @__on_args__; end
      def __on_args__=(val); @__on_args__ = val; end
    end

    if self.driver.nil?
      config = @__context__.respond_to?(:config) ? @__context__.config : nil
      options = @__context__.respond_to?(:options) ? @__context__.options : {}
      driver = Tengine::Core::Driver.new({
          :name => self.driver_name, # self.name.gsub(/:/, 'Colon'),
          :version => Tengine::Core::Setting.dsl_version,
          :enabled => config ? !config[:tengined][:skip_enablement] : true,   # driverを有効化して登録するかのオプション
          :enabled_on_activation => options[:enabled_on_activation].nil? || options[:enabled_on_activation],  # DSLに記述されているオプション
          :target_class_name => self.name,
        })
      driver.create_session
      driver.save!
      @__context__.driver = driver
    end

    def self.method_added(method_name)
      return unless @__context__.__on_args__
      args = @__context__.__on_args__
      @__context__.__on_args__ = nil
      driver = @__context__.driver
      return unless driver
      driver.reload
      options = args.extract_options!
      handler = driver.handlers.create!({
          :event_type_names => args,
          :target_instantiation_key => :instance_method,
          :target_method_name => method_name.to_s
        }.update(options))
      args.each do |event_type_name|
        driver.handler_paths.create!(:event_type_name => event_type_name, :handler_id => handler.id)
      end
    end

    def self.singleton_method_added(method_name)
      return if method_name == :singleton_method_added
      # def self.hoge... と class << self; def baz...; end ではselfが異なる
      # (前者はclass自身、後者はclassのsingleton_classになる)ので、差異を吸収するために
      # selfが前者の場合@__context__には後者への参照が設定されており、
      # selfが後者の場合には、@__context__はnilなので、selfを使うことによって
      # 同じインスタンスの__on_args__を使用することが可能になります。
      context = @__context__ || self
      return unless context.__on_args__
      args = context.__on_args__
      context.__on_args__ = nil
      driver = context.driver
      return unless driver
      driver.reload
      options = args.extract_options!
      handler = driver.handlers.create!({
          :event_type_names => args,
          :target_instantiation_key => :static,
          :target_method_name => method_name.to_s
        }.update(options))
      # puts "handler: #{handler.inspect}\n#{args.inspect}"
      args.each do |event_type_name|
        driver.handler_paths.create!(:event_type_name => event_type_name, :handler_id => handler.id)
      end
    end
  end

  module ClassMethods
    def driver_name
      return nil if self.name.nil?
      (self < Tengine::Core::Driveable::ByDsl) ? self.name.underscore : self.name
    end

    def driver
      unless @driver
        driver_attrs = {
          :name => self.driver_name, # self.name.gsub(/:/, 'Colon'),
          :version => Tengine::Core::Setting.dsl_version
        }
        @driver = Tengine::Core::Driver.first(:conditions => driver_attrs)
      end
      @driver
    end

    def session
      @__session_wrapper__ ||= Tengine::Core::SessionWrapper.new(driver.session)
    end

    def on(*args, &block)
      context = @__context__ || self
      options = args.extract_options!
      event_type_names = args
      if block
        filepath, lineno = *block.source_location
        filepath = context.config.relative_path_from_dsl_dir(filepath)
        options.update(:filepath => filepath, :lineno => lineno)
        filter_def = nil
        handler = nil
        if event_type_names.length == 1 && event_type_names.first.is_a?(Tengine::Core::DslFilterDef)
          filter_def = event_type_names.first
          options[:filter] = filter_def.filter
          event_type_names = filter_def.event_type_names
          base_method_name = event_type_names.map(&:to_s).join("_")
          driver = context.driver
          driver.reload
          handler = driver.handlers.new({
              :event_type_names => event_type_names,
              :target_instantiation_key => :instance_method,
            }.update(options))
          # フィルタ付きの場合は単純なイベントハンドラ名だけではメソッド名として表現できないので
          # handler自身のIDをメソッド名に含めます。
          method_name = "#{base_method_name}_#{handler.id.to_s}"
          handler.target_method_name = method_name.to_s
          handler.save!
          event_type_names.each do |event_type_name|
            driver.handler_paths.create!(:event_type_name => event_type_name, :handler_id => handler.id)
          end
        else
          method_name = event_type_names.map(&:to_s).join("_")
          context.__on_args__ = event_type_names.map(&:to_s) + [options]
        end
        case block.arity
        when 1 then
          define_method(method_name, &block)
        when 0 then
          impl_method_name = "__#{method_name}_impl__"
          self.instance_eval do
            define_method(method_name) do |event|
              @__event__ = Tengine::Core::EventWrapper.new(event)
              begin
                send(impl_method_name)
              ensure
                @__event__ = nil
              end
            end
            define_method(impl_method_name, &block)
          end
        else
          raise Tengine::Core::DslError, "#{block.artity} aritties block given"
        end
        # handler.save! if handler
      else
        filepath, lineno = *caller.first.sub(/:in.+\Z/, '').split(/:/, 2)
        options.update(:filepath => filepath, :lineno => lineno)
        context.__on_args__ = ( args + [options] )
      end
    end
  end

  def session
    self.class.session
  end


  module ByDsl
    extend ActiveSupport::Concern

    included do
      @__context__ = self.singleton_class
      @__context__.instance_eval do
        def config; @config; end
        def config=(val); @config = val; end

        def options; @options; end
        def options=(val); @options = val; end
      end
    end

    def event
      @__event__
    end

    def kernel
      ev = event 
      ev ? ev.kernel : nil
    end

    def ack?; kernel.ack?; end
    def submit; kernel.submit; end

  end

end
