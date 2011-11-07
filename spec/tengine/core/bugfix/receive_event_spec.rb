# -*- coding: utf-8 -*-
require 'spec_helper'
require 'amqp'

describe "receive_event" do
  before do
    Tengine::Core::Event.delete_all
    Tengine::Core::Driver.delete_all
    Tengine::Core::Session.delete_all

    # DSLのloadからbindまで
    @config = Tengine::Core::Config.new({
        :tengined => {
          :load_path => File.expand_path('./use_event_in_handler_dsl.rb', File.dirname(__FILE__)),
          :wait_activation => false,
          :confirmation_threashold => 'info'
        },
      })
    @config.dsl_version.should_not be_blank
    @bootstrap = Tengine::Core::Bootstrap.new(@config)
    @bootstrap.load_dsl
    @kernel = Tengine::Core::Kernel.new(@config)
    @kernel.bind

    # キューの mock を生成
    @mock_channel = mock(:channel)
    @mock_queue = mock(:queue)

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
    EM.should_receive(:run).and_yield
    EM.stub(:defer) {|x, y| x.call; y.call(nil) if y }
    EM.stub(:add_periodic_timer)
    mock_connection = mock(:connection)
    AMQP.should_receive(:connect).with({:user=>"guest", :pass=>"guest", :vhost=>"/",
        :logging=>false, :insist=>false, :host=>"localhost", :port=>5672}).and_return(mock_connection)
    mock_connection.should_receive(:on_tcp_connection_loss)
    mock_connection.should_receive(:after_recovery)
    mock_connection.should_receive(:on_closed)
    mock_connection.stub(:connected?).and_return(true)

    mock_mq = Tengine::Mq::Suite.new(@kernel.config[:event_queue])
    Tengine::Mq::Suite.should_receive(:new).with(@kernel.config[:event_queue]).and_return(mock_mq)
    mock_mq.should_receive(:queue).exactly(2).times.and_return(@mock_queue)
    mock_mq.stub(:wait_for_connection).and_yield

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
    @mock_queue.should_receive(:subscribe).with(:ack => true, :nowait => true).and_yield(@header, @raw_event.to_json)
    @header.should_receive(:ack)

    count = lambda{ Tengine::Core::Event.where(:event_type_name => :event01, :confirmed => true).count }
    @kernel.should_receive(:setup_mq_connection)
    STDOUT.should_receive(:puts).with("uuid1:handler01")
    expect{ @kernel.start }.should change(count, :call).by(1) # イベントが登録されていることを検証
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
