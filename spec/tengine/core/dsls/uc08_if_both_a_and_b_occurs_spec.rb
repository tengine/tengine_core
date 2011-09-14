# -*- coding: utf-8 -*-
require 'spec_helper'

describe "uc08_if_both_a_and_b_occurs" do
  before do
    Tengine::Core::Driver.delete_all
    Tengine::Core::Session.delete_all
    config = Tengine::Core::Config.new({
        :tengined => {
          :load_path => File.expand_path('../../../../examples/uc08_if_both_a_and_b_occurs.rb', File.dirname(__FILE__)),
        },
      })
    @bootstrap = Tengine::Core::Bootstrap.new(config)
    @bootstrap.load_dsl
    @kernel = Tengine::Core::Kernel.new(config)
    @kernel.bind
  end

  it "aとbが両方起きたらハンドラが実行されます" do
    mock_headers = mock(:headers)
    mock_headers.should_receive(:ack).exactly(3).times
    raw_event = Tengine::Event.new(:event_type_name => "event08_a")
    @kernel.process_message(mock_headers, raw_event.to_json)
    raw_event = Tengine::Event.new(:event_type_name => "event08_a")
    @kernel.process_message(mock_headers, raw_event.to_json)
    @kernel.context.should_receive(:puts).with("handler08")
    raw_event = Tengine::Event.new(:event_type_name => "event_08_b")
    @kernel.process_message(mock_headers, raw_event.to_json)
  end
end
