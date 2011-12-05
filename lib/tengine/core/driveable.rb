# -*- coding: utf-8 -*-
require 'tengine/core'

# イベントドライバ定義モジュール
#
module Tengine::Core::Driveable
  extend ActiveSupport::Concern

  included do
    self.driver = Tengine::Core::Driver.create!(
      :name => self.name.gsub(/:/, 'Colon'),
      :target_class_name => self.name,
      :version => Tengine::Core::Setting.dsl_version
      )

    def self.method_added(method_name)
      return unless @__event_type_names__ || @__event_type_names__.empty?
      driver.reload
      handler = driver.handlers.create!({
          :event_type_names => @__event_type_names__,
          :target_instantiation_key => :instance_method,
          :target_method_name => method_name.to_s
        }.update(@__last_options__))
      @__handler_paths__ = @__event_type_names__.map do |event_type_name|
        driver.handler_paths.create!(:event_type_name => event_type_name, :handler_id => handler.id)
      end
    end
  end

  module ClassMethods
    attr_accessor :driver

    def on(*args)
      @__last_options__ = args.extract_options!
      @__event_type_names__ = args
      filepath, lineno = *caller.first.sub(/:in.+\Z/, '').split(/:/, 2)
      @__last_options__.update(:filepath => filepath, :lineno => lineno)
    end

  end


end
