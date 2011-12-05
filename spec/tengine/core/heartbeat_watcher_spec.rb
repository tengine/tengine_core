# -*- coding: utf-8 -*-
require 'spec_helper'
require 'amqp'

require_relative '../../../lib/tengine/core/heartbeat_watcher'
require 'tengine/mq/suite'

describe Tengine::Core::HeartbeatWatcher do
  before do
    Tengine::Core::Event.delete_all
    @uuid = UUID.new
  end

  subject do
    Tengine::Core::HeartbeatWatcher.new(%w[--heartbeat-hbw-interval=30])
  end

  describe "#search_for_invalid_heartbeat" do

    before do
      @fixtures = Array.new
      @fixtures << Tengine::Core::Event.new(key: @uuid.generate, event_type_name: "job.heartbeat.tengine", occurred_at: 1.day.ago)
      @fixtures << Tengine::Core::Event.new(key: @uuid.generate, event_type_name: "job.heartbeat.tengine", occurred_at: 1.second.ago)
      @fixtures.each {|i| i.save! }
    end

    it "古いものを検索してくる" do
      set = []
      EM.run do
        subject.search_for_invalid_heartbeat do |i|
          set << i
        end
        EM.add_timer 0.1 do EM.stop end
      end

      set.should include(@fixtures[0])
      set.should_not include(@fixtures[1])
    end
  end

  describe "#send_last_event" do
    it "finished.process.hbw.tengineの発火" do
      sender = mock(:sender)
      subject.stub(:sender).and_return(sender)
      sender.should_receive(:fire).with("finished.process.hbw.tengine", an_instance_of(Hash))
      sender.should_receive(:stop)
      subject.send_last_event
    end
  end

  describe "#send_periodic_event" do
    it "hbw.heartbeat.tengineの発火" do
      sender = mock(:sender)
      subject.stub(:sender).and_return(sender)
      sender.should_receive(:fire).with("hbw.heartbeat.tengine", an_instance_of(Hash))
      sender.stub(:fire).with("finished.process.hbw.tengine", an_instance_of(Hash)) # 来るかも
      subject.send_periodic_event
    end
  end

  describe "#send_invalidate_event" do
    it "引数のイベントのtypeを書き換えて、他は同じで発火" do
      e0 = Tengine::Core::Event.new(key: @uuid.generate, event_type_name: "job.heartbeat.tengine", occurred_at: 1.day.ago)
      sender = mock(:sender)
      subject.stub(:sender).and_return(sender)
      sender.should_receive(:fire).with(an_instance_of(Tengine::Event), an_instance_of(Hash)) do |e1, h|
        e1.event_type_name.should == "foobar"
        e1.occurred_at.should == e0.occurred_at
        e1.key.should == e0.key
      end

      subject.send_invalidate_event "foobar", e0
    end
  end

  describe "#sender" do
    before do
      conn = mock(:connection)
      conn.stub(:on_tcp_connection_loss)
      conn.stub(:after_recovery)
      conn.stub(:on_closed)
      AMQP.stub(:connect).with(an_instance_of(Hash)).and_return(conn)
    end
    subject { Tengine::Core::HeartbeatWatcher.new([]).sender }
    it { should be_kind_of(Tengine::Event::Sender) }
  end

  describe "#run" do
    it "各種timerを登録する" do
      EM.stub(:run).and_yield
      Daemons.stub(:run_proc).with(anything, anything).and_yield
      EM.should_receive(:add_periodic_timer).exactly(2).times
      Tengine::Core::MethodTraceable.stub(:disabled=)
      sender = mock(:sender)
      sender.stub(:wait_for_connection).and_yield
      subject.stub(:sender).and_return(sender)
      subject.instance_eval { @config }.stub(:setup_loggers)
      subject.run __FILE__
    end
  end
end
