# -*- coding: utf-8 -*-
require 'spec_helper'

describe "uc81_raise_runtime_error" do
  before do 
    Tengine::Core::HandlerPath.delete_all
    Tengine::Core::Driver.delete_all
    Tengine::Core::Session.delete_all
    @dsl_path = File.expand_path('../../../../examples/uc81_raise_runtime_error.rb', File.dirname(__FILE__))
    @config = Tengine::Core::Config::Core.new({
        :tengined => {
          :load_path => @dsl_path,
        },
      })
    @bootstrap = Tengine::Core::Bootstrap.new(@config)
    @kernel = Tengine::Core::Kernel.new(@config)
  end

  it "例外がraiseされると、イベント処理エラーイベントをfireする" do
    @bootstrap.load_dsl
    @kernel.bind

    driver = Tengine::Core::Driver.first
    driver.enabled.should == true
    driver.version.should == @config.dsl_version
    path = Tengine::Core::HandlerPath.first
    path.event_type_name.should == "event81"
    path.driver_id.should == driver.id
    Tengine::Core::HandlerPath.default_driver_version.should == @config.dsl_version

    mock_headers = mock(:headers)
    mock_headers.should_receive(:ack)
    raw_event = Tengine::Event.new(:event_type_name => "event81")
    @kernel.should_receive(:fire).with("event81.error.tengined",
      :properties => {
        :original_event => instance_of(String),
        :error_class_name => "RuntimeError",
        :error_message => "by driver81",
        :error_backtrace => instance_of(Array),
        # :block_source_location => "#{@dsl_path}:6" # 6はブロックの行番号
      })
    Tengine::Core::Kernel.temp_exception_reporter(:except_test) do
      expect{
        @kernel.process_message(mock_headers, raw_event.to_json)
      }.to_not raise_error
    end
  end

end
