# -*- coding: utf-8 -*-
require 'tengine/rspec'

# イベントドライバのテストのためのメソッドを追加するモジュールです。
# includeしてお使いください。
module Tengine::RSpec::Extension
  extend ActiveSupport::Concern

  module ClassMethods
    def target_dsl(dsl_path)
      before do
        Tengine::Core::Driver.delete_all
        Tengine::Core::Session.delete_all
        @__dsl_path__ = dsl_path
        @__config__ = Tengine::Core::Config.new({
            :tengined => { :load_path => @__dsl_path__ },
          })
        @__bootstrap__ = Tengine::Core::Bootstrap.new(@__config__)
        @__bootstrap__.load_dsl
        @__kernel__ = Tengine::Core::Kernel.new(@__config__)
        @__kernel__.bind
        @__tengine__ = Tengine::RSpec::ContextWrapper.new(@__kernel__)
      end
    end

    def driver(driver_name)
      before do
        @__driver__ = Tengine::Core::Driver.first(:conditions => {:name => driver_name})
        session = @__driver__.session
        @__session__ = Tengine::Core::SessionWrapper.new(session)
      end
    end
  end

  module InstanceMethods
    def session
      @__session__
    end

    def tengine
      @__tengine__
    end
  end

end
