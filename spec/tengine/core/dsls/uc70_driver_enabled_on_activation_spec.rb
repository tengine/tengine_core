# -*- coding: utf-8 -*-
require 'spec_helper'

describe "uc70_driver_enabled_on_activation" do
  before do
    Tengine::Core::Driver.delete_all
    Tengine::Core::Session.delete_all
    @config = Tengine::Core::Config::Core.new({
        :tengined => {
          :load_path => File.expand_path('../../../../examples/uc70_driver_enabled_on_activation.rb', File.dirname(__FILE__)),
          :skip_enablement => true,
        },
      })
    @bootstrap = Tengine::Core::Bootstrap.new(@config)
    @kernel = Tengine::Core::Kernel.new(@config)
  end

  it "普通に登録されて、起動後は有効になっている" do
    @bootstrap.load_dsl
    driver = Tengine::Core::Driver.first
    driver.enabled.should == false
    driver.enabled_on_activation.should == true
    @bootstrap.enable_drivers
    driver.reload
    driver.enabled.should == true
    driver.enabled_on_activation.should == true
    @kernel.bind
    #
    klass = driver.target_class_name.constantize
    obj = klass.new
    klass.should_receive(:new).and_return(obj)
    obj.should_receive(:puts).with("handler70")
    mock_headers = mock(:headers)
    mock_headers.should_receive(:ack)
    raw_event = Tengine::Event.new(:event_type_name => "event70")
    @kernel.process_message(mock_headers, raw_event.to_json)
  end

end
