# -*- coding: utf-8 -*-
require 'spec_helper'

describe "uc62_session_in_driver" do
  before do
    Tengine::Core::Driver.delete_all
    Tengine::Core::Session.delete_all
    config = Tengine::Core::Config::Core.new({
        :tengined => {
          :load_path => File.expand_path('../../../../examples/uc62_session_in_driver.rb', File.dirname(__FILE__)),
        },
      })
    @bootstrap = Tengine::Core::Bootstrap.new(config)
    @kernel = Tengine::Core::Kernel.new(config)
  end

  it "ロード後にはsessionに値が入っている" do
    @bootstrap.load_dsl
    driver62 = Tengine::Core::Driver.first
    session = driver62.session
    session.should_not be_nil
    session.properties.should == { 'foo' => 100}
    @kernel.bind
    mock_headers = mock(:headers)
    mock_headers.should_receive(:ack).twice
    raw_event = Tengine::Event.new(:event_type_name => "event62")
    @kernel.process_message(mock_headers, raw_event.to_json)
    session.reload
    session.properties.should == { 'foo' => 101}
    raw_event = Tengine::Event.new(:event_type_name => "event62")
    @kernel.process_message(mock_headers, raw_event.to_json)
    session.reload
    session.properties.should == { 'foo' => 102}
  end

end
