# -*- coding: utf-8 -*-
require 'spec_helper'

describe "uc64_safety_countup" do
  before do
    Tengine::Core::Driver.delete_all
    Tengine::Core::Session.delete_all
    @dsl_path = File.expand_path('../../../../../examples/uc64_safety_countup.rb', File.dirname(__FILE__))
    config = Tengine::Core::Config.new({
        :tengined => {
          :load_path => @dsl_path,
        },
      })
    @bootstrap = Tengine::Core::Bootstrap.new(config)
    @bootstrap.load_dsl
    @kernel1 = Tengine::Core::Kernel.new(config)
    @kernel2 = Tengine::Core::Kernel.new(config)
  end

  it "同時にロードして、同時に更新しても正しく更新することができる" do
    driver64 = Tengine::Core::Driver.first
    session = driver64.session
    session.should_not be_nil
    session.properties.should == { 'foo' => 100}
    @kernel1.bind
    @kernel2.bind
    mock_headers = mock(:headers)
    mock_headers.should_receive(:ack).twice

    test_session_wrapper_class = Class.new(Tengine::Core::SessionWrapper) do
      def __get_properties__(*args)
        result = super
        Fiber.yield
        result
      end
    end

    f1 = Fiber.new{
      raw_event1 = Tengine::Event.new(:event_type_name => "event64")
      session_wrapper1 = test_session_wrapper_class.new(Tengine::Core::Session.find(session.id))
      @kernel1.context.should_receive(:session).and_return(session_wrapper1)
      @kernel1.process_message(mock_headers, raw_event1.to_json)
    }
    f1.resume

    f2 = Fiber.new{
      raw_event2 = Tengine::Event.new(:event_type_name => "event64")
      session_wrapper2 = test_session_wrapper_class.new(Tengine::Core::Session.find(session.id))
      @kernel2.context.should_receive(:session).and_return(session_wrapper2)
      @kernel2.process_message(mock_headers, raw_event2.to_json)
    }
    f2.resume

    f1.resume
    session.reload
    session.properties.should == { 'foo' => 101}

    f2.resume
    session.reload
    session.properties.should == { 'foo' => 101}

    f2.resume
    session.reload
    session.properties.should == { 'foo' => 102}
  end


  it "リトライの回数を超えたら例外をraiseする" do
    driver64 = Tengine::Core::Driver.first
    session = driver64.session
    session.should_not be_nil
    session.properties.should == { 'foo' => 100}
    @kernel1.bind
    @kernel2.bind
    mock_headers = mock(:headers)
    mock_headers.should_receive(:ack).exactly(5).times

    test_session_wrapper_class = Class.new(Tengine::Core::SessionWrapper) do
      def __get_properties__(*args)
        result = super
        Fiber.yield
        result
      end
    end

    # @kernel1の経路で３回イベントがくる間、@kernel2は常に先を越されて、最初のイベントによる更新もできないケース
    f1 = Fiber.new{
      4.times do
        raw_event1 = Tengine::Event.new(:event_type_name => "event64")
        session_wrapper1 = test_session_wrapper_class.new(Tengine::Core::Session.find(session.id))
        @kernel1.context.should_receive(:session).and_return(session_wrapper1)
        @kernel1.process_message(mock_headers, raw_event1.to_json)
      end
    }
    f1.resume

    f2 = Fiber.new{
      raw_event2 = Tengine::Event.new(:event_type_name => "event64")
      session_wrapper2 = test_session_wrapper_class.new(Tengine::Core::Session.find(session.id))
      @kernel2.context.should_receive(:session).and_return(session_wrapper2)
      @kernel2.context.should_receive(:fire).with("event64.error.tengined",
      :properties => {
        :original_event => instance_of(String),
        :error_class_name => "Mongo::OperationFailure",
        :error_message => %[Database command 'findandmodify' failed: {"errmsg"=>"No matching object found", "ok"=>0.0}],
        :error_backtrace => instance_of(Array),
        :block_source_location => "#{@dsl_path}:8" # 8はブロックの行番号
      })
      @kernel2.process_message(mock_headers, raw_event2.to_json)
    }
    f2.resume

    f1.resume
    session.reload
    session.properties.should == { 'foo' => 101}
    f2.resume
    session.reload
    session.properties.should == { 'foo' => 101}

    f1.resume
    session.reload
    session.properties.should == { 'foo' => 102}
    f2.resume
    session.reload
    session.properties.should == { 'foo' => 102}

    f1.resume
    session.reload
    session.properties.should == { 'foo' => 103}
    f2.resume
    session.reload
    session.properties.should == { 'foo' => 103}

    f1.resume
    session.reload
    session.properties.should == { 'foo' => 104}

  end

end
