# -*- coding: utf-8 -*-
require 'spec_helper'
require 'amqp'

require_relative '../../../lib/tengine/core/scheduler'
require 'tengine/mq/suite'

describe Tengine::Core::Scheduler do
  before do
    Tengine::Core::Schedule.delete_all
    @uuid = UUID.new
  end

  subject do
    Tengine::Core::Scheduler.new([])
  end

  describe "#search_for_schedule" do

    before do
      @fixtures = Array.new
      @fixtures << Tengine::Core::Schedule.new(event_type_name: "stop.execution.job.tengine", scheduled_at: 1.day.ago)
      @fixtures << Tengine::Core::Schedule.new(event_type_name: "stop.execution.job.tengine", scheduled_at: Time.now + 10)
      @fixtures << Tengine::Core::Schedule.new(event_type_name: "stop.execution.job.tengine", scheduled_at: 1.day.ago, status: Tengine::Core::Schedule::FIRED)
      @fixtures.each {|i| i.save! }
    end

    it "古いものを検索してくる" do
      EM.stub(:next_tick).and_yield
      set = []
      subject.search_for_schedule do |i|
        set << i
      end

      set.should include(@fixtures[0])
      set.should_not include(@fixtures[1])
      set.should_not include(@fixtures[2])
    end
  end

  describe "#send_last_event" do
    it "finished.process.atd.tengineの発火" do
      sender = mock(:sender)
      subject.stub(:sender).and_return(sender)
      sender.should_receive(:fire).with("finished.process.atd.tengine", an_instance_of(Hash))
      subject.send_last_event
    end
  end

  describe "#send_periodic_event" do
    it "atd.heartbeat.tengineの発火" do
      sender = mock(:sender)
      subject.stub(:sender).and_return(sender)
      sender.should_receive(:fire).with("atd.heartbeat.tengine", an_instance_of(Hash))
      sender.stub(:fire).with("finished.process.atd.tengine", an_instance_of(Hash)) # 来るかも
      subject.send_periodic_event
    end
  end

  describe "#send_scheduled_event" do
    it "スケジュールされたイベントの発火" do
      s0 = Tengine::Core::Schedule.new(event_type_name: "test.event.not.tengine", source_name: "test://localhost/dev/null")
      sender = mock(:sender)
      subject.stub(:sender).and_return(sender)
      sender.should_receive(:fire).with(s0.event_type_name, an_instance_of(Hash)) do |e1, h|
        h[:source_name].should == s0.source_name
      end

      subject.send_scheduled_event s0
    end
  end

  describe "#mark_schedule_done" do
    it "実行したスケジュールは終了とする" do
      s0 = Tengine::Core::Schedule.new(event_type_name: "test.event.not.tengine", source_name: "test://localhost/dev/null")
      s0.save
      subject.mark_schedule_done s0
      s0.reload
      s0.status.should == Tengine::Core::Schedule::FIRED
    end

    it "すでに終了していたら何もしない" do
      s0 = Tengine::Core::Schedule.new(event_type_name: "test.event.not.tengine", source_name: "test://localhost/dev/null", status: Tengine::Core::Schedule::FIRED)
      s0.save
      s0.reload
      t = s0.updated_at
      subject.mark_schedule_done s0
      s0.reload
      s0.updated_at.should == t
    end
  end

  describe "#sender" do
    before do
      conn = mock(:connection)
      conn.stub(:on_tcp_connection_loss)
      conn.stub(:after_recovery)
      conn.stub(:on_closed)
      AMQP.stub(:connect).with({:user=>"guest", :pass=>"guest", :vhost=>"/",
          :logging=>false, :insist=>false, :host=>"localhost", :port=>5672}).and_return(conn)
    end
    subject { Tengine::Core::Scheduler.new([]).sender }
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
