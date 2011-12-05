# -*- coding: utf-8 -*-
require 'spec_helper'

describe Tengine::Core::DslBinder do

  describe :__evaluate__ do
    before do
      Tengine::Core::Driver.delete_all
      Tengine::Core::HandlerPath.delete_all
    end

    context "DSLのファイルを指定する場合" do
      before do
        config = Tengine::Core::Config::Core.new({
            :tengined => {
              :load_path => File.expand_path('../../../examples/uc01_execute_processing_for_event.rb', File.dirname(__FILE__))
            }
        })
        @binder = Tengine::Core::DslBindingContext.new(mock(:kernel))
        @binder.extend(Tengine::Core::DslBinder)
        @binder.config = config

        @driver = Tengine::Core::Driver.new(:name => "driver01", :version => config.dsl_version)
        @handler1 = @driver.handlers.new(:filepath => "uc01_execute_processing_for_event.rb", :lineno => 7, :event_type_names => ["event01"])
        @driver.save!
      end

      it "イベントハンドラ定義を評価して、ドライバとハンドラを保持する" do
        @driver.handlers.count.should == 1
        @binder.__evaluate__
        @binder.should_receive(:puts).with("handler01")
        @binder.__block_bindings__[@handler1.id.to_s].call
      end

      it "同じイベント種別で複数のハンドラが登録されていた場合でもエラーにはならない" do
        @handler2 = @driver.handlers.new(:event_type_names => ["event01"], :filepath => "path/to/driver.rb", :lineno => 7)
        @driver.save!
        @driver.handlers.count.should == 2

        @binder.__evaluate__
      end
    end

    context "DSLのファイルを指定しない場合" do
      before do
        config = Tengine::Core::Config::Core.new({
            :tengined => {
              :load_path => File.expand_path('../../../examples', File.dirname(__FILE__))
            }
        })
        @binder = Tengine::Core::DslBindingContext.new(mock(:kernel))
        @binder.extend(Tengine::Core::DslBinder)
        @binder.config = config

        @binder.config.should_receive(:dsl_file_paths).and_return([
            "#{config[:tengined][:load_path]}/uc01_execute_processing_for_event.rb",
            "#{config[:tengined][:load_path]}/uc02_fire_another_event.rb",
            "#{config[:tengined][:load_path]}/uc03_2handlers_for_1event.rb",
          ])

        @driver1 = Tengine::Core::Driver.new(:name => "driver01", :version => config.dsl_version)
        @handler1 = @driver1.handlers.new(:filepath => "uc01_execute_processing_for_event.rb", :lineno => 7, :event_type_names => ["event01"])
        @driver1.save!
        @driver2 = Tengine::Core::Driver.new(:name => "driver02", :version => config.dsl_version)
        @handler2_1 = @driver2.handlers.new(:filepath => "uc02_fire_another_event.rb", :lineno => 7, :event_type_names => ["event02_1"])
        @handler2_2 = @driver2.handlers.new(:filepath => "uc02_fire_another_event.rb", :lineno => 12, :event_type_names => ["event02_2"])
        @driver2.save!
        @driver3 = Tengine::Core::Driver.new(:name => "driver03", :version => config.dsl_version)
        @handler3_1 = @driver3.handlers.new(:filepath => "uc03_2handlers_for_1event.rb", :lineno => 8, :event_type_names => ["event03"])
        @handler3_2 = @driver3.handlers.new(:filepath => "uc03_2handlers_for_1event.rb", :lineno => 12, :event_type_names => ["event03"])
        @driver3.save!
      end

      it "イベントハンドラ定義を評価して、ドライバとハンドラを保持する" do
        @binder.__evaluate__

        @binder.should_receive(:puts).with("handler01")
        @binder.__block_bindings__[@handler1.id.to_s].call

        @binder.should_receive(:puts).with("handler02_1")
        @binder.should_receive(:fire).with(:event02_2)
        @binder.__block_bindings__[@handler2_1.id.to_s].call

        @binder.should_receive(:puts).with("handler03_1")
        @binder.should_receive(:puts).with("handler03_2")
        @binder.__block_bindings__[@handler3_1.id.to_s].call
        @binder.__block_bindings__[@handler3_2.id.to_s].call
      end
    end
  end

end
