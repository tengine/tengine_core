# -*- coding: utf-8 -*-
require 'spec_helper'

describe "uc52_commit_event_after_all_handler_submit" do
  before do
    config = Tengine::Core::Config.new({
        :tengined => {
          :load_path => File.expand_path('../../../../../examples/uc52_never_commit_event_unless_all_handler_submit.rb', File.dirname(__FILE__)),
        },
      })
    @bootstrap = Tengine::Core::Bootstrap.new(config)
    @bootstrap.load_dsl
    @kernel = Tengine::Core::Kernel.new(config)
    @kernel.bind
  end

  it "一つsubmitしないハンドラがあるのでackされません" do
    dsl_env = @kernel.dsl_env
    dsl_env.should_receive(:puts).with("handler52_alt1_1 unacknowledged")
    dsl_env.should_receive(:puts).with("handler52_alt1_2 unacknowledged")
    dsl_env.should_receive(:puts).with("handler52_alt1_3 unacknowledged")
    mock_headers = mock(:headers)
    mock_headers.should_not_receive(:ack)
    raw_event = Tengine::Event.new(:event_type_name => "event52_alt1")
    @kernel.process_message(mock_headers, raw_event.to_json)
  end

end
