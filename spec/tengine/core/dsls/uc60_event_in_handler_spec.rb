# -*- coding: utf-8 -*-
require 'spec_helper'

describe "uc62_session_in_driver" do
  before do
    Tengine::Core::Driver.delete_all
    Tengine::Core::Session.delete_all
    config = Tengine::Core::Config::Core.new({
        :tengined => {
          :load_path => File.expand_path('../../../../examples/uc60_event_in_handler.rb', File.dirname(__FILE__)),
        },
      })
    @bootstrap = Tengine::Core::Bootstrap.new(config)
    @bootstrap.load_dsl
    @kernel = Tengine::Core::Kernel.new(config)
    @kernel.bind
  end

  it "ロード後にはsessionに値が入っている" do
    driver = Tengine::Core::Driver.first
    klass = driver.target_class_name.constantize
    obj = klass.new
    klass.should_receive(:new).and_return(obj)
    obj.should_receive(:puts).with(/^handler60: \[.*\]$/)

    mock_headers = mock(:headers)
    mock_headers.should_receive(:ack)
    raw_event = Tengine::Event.new(:event_type_name => "event60")
    @kernel.process_message(mock_headers, raw_event.to_json)
  end
end
