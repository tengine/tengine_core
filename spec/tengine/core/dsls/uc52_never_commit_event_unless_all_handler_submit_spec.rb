# -*- coding: utf-8 -*-
require 'spec_helper'

describe "uc52_commit_event_after_all_handler_submit" do
  before do
    Tengine::Core::HandlerPath.delete_all
    Tengine::Core::Driver.delete_all
    Tengine::Core::Session.delete_all
    config = Tengine::Core::Config::Core.new({
        :tengined => {
          :load_path => File.expand_path('../../../../examples/uc52_never_commit_event_unless_all_handler_submit.rb', File.dirname(__FILE__)),
        },
      })
    @bootstrap = Tengine::Core::Bootstrap.new(config)
    @kernel = @bootstrap.send(:kernel)
    @bootstrap.load_dsl
    @kernel.bind
  end

  it "一つsubmitしないハンドラがあるのでackされません" do
    context = @kernel.context
    @kernel.ack_policies.should == {"event52_alt1"=>:after_all_handler_submit}
    @kernel.ack?.should == nil
    STDOUT.should_receive(:puts).with("handler52_alt1_1 unacknowledged")
    STDOUT.should_receive(:puts).with("handler52_alt1_2 unacknowledged")
    STDOUT.should_receive(:puts).with("handler52_alt1_3 unacknowledged")
    mock_headers = mock(:headers)
    mock_headers.should_not_receive(:ack)
    raw_event = Tengine::Event.new(:event_type_name => "event52_alt1")
    @kernel.before_delegate = lambda do
      @kernel.all_submitted?.should == false
    end
    @kernel.process_message(mock_headers, raw_event.to_json)
    @kernel.ack?.should == false
  end

end
