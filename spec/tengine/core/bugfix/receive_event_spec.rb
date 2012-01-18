# -*- coding: utf-8 -*-
require 'spec_helper'
require 'amqp'

describe "receive_event" do
  before do
    Tengine::Core::Event.delete_all
    Tengine::Core::Driver.delete_all
    Tengine::Core::Session.delete_all

    # DSLのloadからbindまで
    @config = Tengine::Core::Config::Core.new({
        :tengined => {
          :load_path => File.expand_path('./use_event_in_handler_dsl.rb', File.dirname(__FILE__)),
          :wait_activation => false,
          :confirmation_threshold => 'info'
        },
      })
    @config.dsl_version.should_not be_blank
    @bootstrap = Tengine::Core::Bootstrap.new(@config)
    @bootstrap.load_dsl
    @kernel = Tengine::Core::Kernel.new(@config)
    @kernel.bind

    # キューの mock を生成
    @mock_mq = mock(:mq)

    @header = AMQP::Header.new(@mock_channel, nil, {
        :routing_key  => "",
        :content_type => "application/octet-stream",
        :priority     => 0,
        :headers      => { },
        :timestamp    => Time.now,
        :type         => "",
        :delivery_tag => 1,
        :redelivered  => false,
        :exchange     => "tengine_event_exchange",
      })
  end

  it "イベントを登録できる" do
    # tengine_fire されるイベントオブジェクト
    @raw_event = Tengine::Event.new(
      :event_type_name => :event01,
      :key => "uuid1",
      'source_name' => "server1",
      :occurred_at => Time.utc(2011,8,11,12,0),
      :level => "1",
      'sender_name' => "server2",
      :properties => {:bar => "ABC", :baz => 999}
      )

    event = @kernel.parse_event(@raw_event.to_json)
    event.event_type_name.should == "event01"
    event.key.should == "uuid1"
    event.source_name.should == "server1"
    event.sender_name.should == "server2"
    event.level.should == "1"
    event.properties.should == {"bar" => "ABC", "baz" => 999}

    @raw_event.event_type_name.should == event.event_type_name
    @raw_event.key.should == event.key
    @raw_event.source_name.should == event.source_name
    @raw_event.sender_name.should == event.sender_name
    @raw_event.level.should == event.level
    @raw_event.properties.should == event.properties

    @kernel.save_event(event)
  end

  it "発火されたイベントを受信して登録できる" do
    # eventmachine と mq の mock を生成
    mock_sender = mock("sender")
    mock_sender.stub(:fire)
    @kernel.stub(:sender).and_return(mock_sender)
    @kernel.stub(:mq).and_return(@mock_mq)

    # subscribe 実施
    @raw_event = Tengine::Event.new(
      :event_type_name => :event01,
      :key => "uuid1",
      'source_name' => "server1",
      :occurred_at => Time.utc(2011,8,11,12,0),
      :level => 2,
      'sender_name' => "server2",
      :properties => {:bar => "ABC", :baz => 999}
      )
    @mock_mq.stub(:initiate_termination).and_yield
    @mock_mq.stub(:unsubscribe).and_yield
    @mock_mq.stub(:stop).and_yield
    @mock_mq.stub(:add_hook)
    @mock_mq.stub(:subscribe).with(:ack => true, :nowait => false, :confirm => an_instance_of(Proc)) do |h, b|
      h[:confirm].yield(mock("confirm-ok"))
      b.yield(@header, @raw_event.to_json)
    end
    @header.should_receive(:ack)

    count = lambda{ Tengine::Core::Event.where(:event_type_name => :event01, :confirmed => true).count }
    @kernel.should_receive(:setup_mq_connection)
    STDOUT.should_receive(:puts).with("uuid1:handler01")
    expect{ @kernel.start { @kernel.stop } }.should change(count, :call).by(1) # イベントが登録されていることを検証
  end

  it "イベントハンドラ内で取得できるイベントは発火されたイベントと同等になる", :bug => true do
    @header.should_receive(:ack).exactly(2)

    # subscribe 実施
    @raw_event1 = Tengine::Event.new(
      :event_type_name => :event01,
      'source_name' => "server1",
      :occurred_at => Time.utc(2011,8,11,12,0),
      :level => 2,
      'sender_name' => "server2",
      )

    # subscribe が発生した後の処理を実行
    STDOUT.should_receive(:puts).with("#{@raw_event1.key}:handler01")
    @kernel.process_message(@header, @raw_event1.to_json)

    @raw_event2 = Tengine::Event.new(
      :event_type_name => :event01,
      'source_name' => "server1",
      :occurred_at => Time.utc(2011,8,11,12,0),
      :level => 2,
      'sender_name' => "server2",
      )

    # subscribe が発生した後の処理を実行
    STDOUT.should_receive(:puts).with("#{@raw_event2.key}:handler01")
    @kernel.process_message(@header, @raw_event2.to_json)
  end

end
