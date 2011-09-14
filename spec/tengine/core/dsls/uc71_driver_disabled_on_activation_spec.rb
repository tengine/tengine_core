# -*- coding: utf-8 -*-
require 'spec_helper'

describe "uc71_driver_disabled_on_activation" do
  before do
    Tengine::Core::Driver.delete_all
    Tengine::Core::Session.delete_all
    @config = Tengine::Core::Config.new({
        :tengined => {
          :load_path => File.expand_path('../../../../../examples/uc71_driver_disabled_on_activation.rb', File.dirname(__FILE__)),
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
    driver.enabled_on_activation.should == false
    @bootstrap.enable_drivers
    driver.reload
    driver.enabled.should == false
    driver.enabled_on_activation.should == false
    @kernel.bind
    #
    @kernel.context.should_not_receive(:puts).with("handler71")
    mock_headers = mock(:headers)
    mock_headers.should_receive(:ack)
    raw_event = Tengine::Event.new(:event_type_name => "event71")
    @kernel.process_message(mock_headers, raw_event.to_json)
  end

end
