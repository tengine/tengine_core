# -*- coding: utf-8 -*-
require 'spec_helper'

describe "uc50_commit_event_at_first" do
  before do
    config = Tengine::Core::Config::Core.new({
        :tengined => {
          :load_path => File.expand_path('../../../../examples/uc50_commit_event_at_first.rb', File.dirname(__FILE__)),
        },
      })
    @bootstrap = Tengine::Core::Bootstrap.new(config)
    @kernel = @bootstrap.send(:kernel)
    @bootstrap.load_dsl
    @kernel.bind
  end

  it "必ずACKされている" do
    STDOUT.should_receive(:puts).with("handler50 acknowledged")
    mock_headers = mock(:headers)
    mock_headers.should_receive(:ack)
    raw_event = Tengine::Event.new(:event_type_name => "event50")
    @kernel.before_delegate = lambda do
      # ハンドラへの処理の委譲後（=すべてのハンドラの実行終了後）ackが呼び出されるはず
      mock_headers.should_not_receive(:ack)
    end
    @kernel.process_message(mock_headers, raw_event.to_json)
  end

end
