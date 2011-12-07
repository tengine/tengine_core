# -*- coding: utf-8 -*-
require 'spec_helper'
require 'amqp'

describe "load_dsl" do

  describe "driver" do
    before do
      Tengine::Core::Driver.delete_all
      Tengine::Core::HandlerPath.delete_all
    end

    context "enabled_on_activation" do
      it "defaultではイベントドライバが有効になる" do
        config = Tengine::Core::Config::Core.new({
            :tengined => {
              :load_path => File.expand_path('../../../../examples/uc01_execute_processing_for_event.rb', File.dirname(__FILE__)),
            }
          })
        kernel = Tengine::Core::Kernel.new(config)
        loader = Tengine::Core::DslLoadingContext.new(kernel)
        loader.extend(Tengine::Core::DslLoader)
        loader.config = config

        loader.__evaluate__
        Tengine::Core::Driver.count.should == 1
        driver = Tengine::Core::Driver.first
        driver.should_not be_nil
        driver.name.should == "driver01"
        driver.version.should == "20110902213500"
        driver.enabled.should == true                  # オプション設定: 有効
        driver.enabled_on_activation.should == true    # DSL設定: 有効
        driver.handlers.count.should == 1
        handler1 = driver.handlers.first
        handler1.event_type_names.should == ["event01"]
        Tengine::Core::HandlerPath.where(:driver_id => driver.id).count.should == 1
        Tengine::Core::HandlerPath.default_driver_version = "20110902213500"
        Tengine::Core::HandlerPath.find_handlers("event01").count.should == 1
      end

      it "マルチプロセス起動時のデフォルト時はイベントドライバが無効になる" do
        config = Tengine::Core::Config::Core.new({
            :tengined => {
              :load_path => File.expand_path('../../../../examples/uc01_execute_processing_for_event.rb', File.dirname(__FILE__)),
              :skip_enablement => true
            }
          })
        kernel = Tengine::Core::Kernel.new(config)
        loader = Tengine::Core::DslLoadingContext.new(kernel)
        loader.extend(Tengine::Core::DslLoader)
        loader.config = config

        loader.__evaluate__
        Tengine::Core::Driver.count.should == 1
        driver = Tengine::Core::Driver.first
        driver.should_not be_nil
        driver.name.should == "driver01"
        driver.version.should == "20110902213500"
        driver.enabled.should == false                 # オプション設定: 無効
        driver.enabled_on_activation.should == true    # DSL設定: 有効
        driver.handlers.count.should == 1
        handler1 = driver.handlers.first
        handler1.event_type_names.should == ["event01"]
        Tengine::Core::HandlerPath.where(:driver_id => driver.id).count.should == 1
        Tengine::Core::HandlerPath.default_driver_version = "20110902213500"
        # driver.enable == false なので取得できないため 0 件
        Tengine::Core::HandlerPath.find_handlers("event01").count.should == 0
      end

      it "DSL内の定義でイベントドライバが無効としている" do
        config = Tengine::Core::Config::Core.new({
            :tengined => {
              :load_path => File.expand_path('../../../../examples/uc71_driver_disabled_on_activation.rb', File.dirname(__FILE__)),
            }
          })
        kernel = Tengine::Core::Kernel.new(config)
        loader = Tengine::Core::DslLoadingContext.new(kernel)
        loader.extend(Tengine::Core::DslLoader)
        loader.config = config

        loader.__evaluate__
        Tengine::Core::Driver.count.should == 1
        driver = Tengine::Core::Driver.first
        driver.should_not be_nil
        driver.name.should == "driver71"
        driver.version.should == "20110902213500"
        driver.enabled.should == true                  # オプション設定: 有効
        driver.enabled_on_activation.should == false   # DSL設定: 無効
        driver.handlers.count.should == 1
        handler1 = driver.handlers.first
        handler1.event_type_names.should == ["event71"]
        Tengine::Core::HandlerPath.where(:driver_id => driver.id).count.should == 1
        Tengine::Core::HandlerPath.default_driver_version = "20110902213500"
        Tengine::Core::HandlerPath.find_handlers("event71").count.should == 1
      end

      it "DSL内の定義でイベントドライバが無効としている" do
        config = Tengine::Core::Config::Core.new({
            :tengined => {
              :load_path => File.expand_path('../../../../examples/uc71_driver_disabled_on_activation.rb', File.dirname(__FILE__)),
              :skip_enablement => true,
            }
          }) 
        kernel = Tengine::Core::Kernel.new(config)
        loader = Tengine::Core::DslLoadingContext.new(kernel)
        loader.extend(Tengine::Core::DslLoader)
        loader.config = config

        loader.__evaluate__
        Tengine::Core::Driver.count.should == 1
        driver = Tengine::Core::Driver.first
        driver.should_not be_nil
        driver.name.should == "driver71"
        driver.version.should == "20110902213500"
        driver.enabled.should == false                  # オプション設定: 無効
        driver.enabled_on_activation.should == false    # DSL設定: 無効
        driver.handlers.count.should == 1
        handler1 = driver.handlers.first
        handler1.event_type_names.should == ["event71"]
        Tengine::Core::HandlerPath.where(:driver_id => driver.id).count.should == 1
        Tengine::Core::HandlerPath.default_driver_version = "20110902213500"
        # driver.enable == false なので取得できないため 0 件
        Tengine::Core::HandlerPath.find_handlers("event71").count.should == 0
      end
    end
  end

end
