# -*- coding: utf-8 -*-
# イベントドライバのテストのためのメソッドを追加するモジュールです。
# includeしてお使いください。
module Tengine::RSpec::Extension
  def target_dsl(dsl_path)
    before do
      Tengine::Core::Driver.delete_all
      Tengine::Core::Session.delete_all
      @__dsl_path__ = File.expand_path("../../app/#{dsl_path}", File.dirname(__FILE__))
      @__config__ = Tengine::Core::Config.new({
          :tengined => { :load_path => @__dsl_path__ },
        })
      @__bootstrap__ = Tengine::Core::Bootstrap.new(@__config__)
      @__bootstrap__.load_dsl
      @__kernel__ = Tengine::Core::Kernel.new(@__config__)
      @__kernel__.bind
      @__tengine__ = TengineContextWrapper.new(@__kernel__)
    end
  end

  def driver(driver_name)
    before do
      @__driver__ = Tengine::Core::Driver.first(:conditions => {:name => driver_name})
      session = @__driver__.session
      @__session__ = Tengine::Core::SessionWrapper.new(session)
    end
  end

  def session
    @__session__
  end

  def tengine
    @__tengine__
  end

end
