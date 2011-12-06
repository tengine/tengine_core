# -*- coding: utf-8 -*-
require 'spec_helper'

describe "uc52_commit_event_after_all_handler_submit" do
  before do
    Tengine::Core::Driver.delete_all
    Tengine::Core::Session.delete_all
    config = Tengine::Core::Config::Core.new({
        :tengined => {
          :load_path => File.expand_path('../../../../examples/uc52_commit_event_after_all_handler_submit.rb', File.dirname(__FILE__)),
        },
      })
    @bootstrap = Tengine::Core::Bootstrap.new(config)
    @bootstrap.load_dsl
    @kernel = Tengine::Core::Kernel.new(config)
    @kernel.bind
  end

  it "必ずACKされている" do
    context = @kernel.context
    context.should_receive(:puts).with("handler52_1 unacknowledged")
    context.should_receive(:puts).with("handler52_2 unacknowledged")
    context.should_receive(:puts).with("handler52_3 unacknowledged")
    mock_headers = mock(:headers)
    @kernel.after_delegate = lambda do
      # ハンドラへの処理の委譲後（=すべてのハンドラの実行終了後）ackが呼び出されるはず
      mock_headers.should_receive(:ack)
    end
    raw_event = Tengine::Event.new(:event_type_name => "event52")
    @kernel.process_message(mock_headers, raw_event.to_json)
  end

end
