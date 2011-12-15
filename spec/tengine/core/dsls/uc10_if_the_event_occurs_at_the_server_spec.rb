# -*- coding: utf-8 -*-
require 'spec_helper'

describe "uc10_if_the_eent_occures_at_the_server" do
  before(:all) do
    Tengine::Core::Driver.delete_all
    Tengine::Core::Session.delete_all
    @dsl_path = File.expand_path('../../../../examples/uc10_if_the_event_occurs_at_the_server.rb', File.dirname(__FILE__))
    @config = Tengine::Core::Config::Core.new({
        :tengined => {
          :load_path => @dsl_path,
        },
      })
    @bootstrap = Tengine::Core::Bootstrap.new(@config)
    @kernel = Tengine::Core::Kernel.new(@config)
    @bootstrap.load_dsl
    @kernel.bind
  end

  before do
    driver = Tengine::Core::Driver.first
    driver.handlers.count.should > 0
    klass = driver.target_class_name.constantize
    @obj = klass.new
    klass.stub(:new).and_return(@obj)
  end

  it "localhostから発火された場合" do
    mock_headers = mock(:headers)
    mock_headers.should_receive(:ack)
    raw_event = Tengine::Event.new(
      :event_type_name => "event10",
      :source_name => "process:localhost/123")
    @obj.should_receive(:puts).with("handler10 for localhost")
    @kernel.process_message(mock_headers, raw_event.to_json)
  end

  it "test_server1から発火された場合" do
    mock_headers = mock(:headers)
    mock_headers.should_receive(:ack)
    raw_event = Tengine::Event.new(
      :event_type_name => "event10",
      :source_name => "process:test_server1/123")
    @obj.should_receive(:puts).with("handler10 for test_server1")
    @kernel.process_message(mock_headers, raw_event.to_json)
  end

  it "another_server1から発火された場合" do
    mock_headers = mock(:headers)
    mock_headers.should_receive(:ack)
    raw_event = Tengine::Event.new(
      :event_type_name => "event10",
      :source_name => "process:another_server1/123")
    @obj.should_not_receive(:puts)
    @kernel.process_message(mock_headers, raw_event.to_json)
  end

end
