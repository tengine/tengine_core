# -*- coding: utf-8 -*-
require 'spec_helper'
require 'amqp'

describe Tengine::Core::Kernel do
  before do
    Tengine::Core::Driver.delete_all
    Tengine::Core::HandlerPath.delete_all
    Tengine::Core::Event.delete_all
  end

  describe :start do
    describe :bind, "handlerのblockをメモリ上で保持" do
      before do
        config = Tengine::Core::Config.new({
            :tengined => {
              :load_path => File.expand_path('../../../../examples/uc01_execute_processing_for_event.rb', File.dirname(__FILE__)),
            },
          })
        @kernel = Tengine::Core::Kernel.new(config)
        @driver = Tengine::Core::Driver.new(:name => "driver01", :version => config.dsl_version, :enabled => true)
        @handler1 = @driver.handlers.new(:filepath => "uc01_execute_processing_for_event.rb", :lineno => 7, :event_type_names => ["event01"])
        @driver.save!
      end

      it "event_type_nameからblockを検索することができる" do
        @kernel.bind
        @kernel.context.__block_for__(@handler1).should_not be_nil
      end
    end

    describe :wait_for_activation, "activate待ち" do
      before do
        config = Tengine::Core::Config.new({
            :tengined => {
              :load_path => File.expand_path('../../../../examples/uc01_execute_processing_for_event.rb', File.dirname(__FILE__)),
              :wait_activation => true,
              :activation_timeout => 3,
              :activation_dir => File.expand_path('.', File.dirname(__FILE__)),
            },
          })
        @kernel = Tengine::Core::Kernel.new(config)
        @driver = Tengine::Core::Driver.new(:name => "driver01", :version => config.dsl_version, :enabled => true)
        @handler1 = @driver.handlers.new(:filepath => "uc01_execute_processing_for_event.rb", :lineno => 7, :event_type_names => ["event01"])
        @driver.save!
        @activation_file_path = "#{@kernel.config[:tengined][:activation_dir]}\/tengined_#{Process.pid}.activation"
      end

      after do
        FileUtils.rm_f(@activation_file_path)
      end

      it "activationファイルが生成されたらactivateされる" do
        @kernel.should_receive(:activate)
        t1 = Thread.new {
          @kernel.start
        }
        t2 = Thread.new {
          FileUtils.touch(@activation_file_path)
        }
        t1.join
        t2.join
      end

      it "activationファイルが生成されないままならタイムアウトになる" do
        lambda {
          @kernel.should_not_receive(:activate)
          @kernel.start
        }.should raise_error(Tengine::Core::ActivationTimeoutError, "activation file found timeout error.")
      end
    end

    describe :activate, "メッセージの受信を開始" do
      before do
        @mock_channel = mock(:channel)
        @mock_queue = mock(:queue)
        @mock_consumer = mock(:consumer)

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

        config = Tengine::Core::Config.new({
            :tengined => {
              :load_path => File.expand_path('../../../../examples/uc01_execute_processing_for_event.rb', File.dirname(__FILE__)),
              :wait_activation => false,
              :confirmation_threashold => 'info'
            },
          })
        @kernel = Tengine::Core::Kernel.new(config)
        @driver = Tengine::Core::Driver.new(:name => "driver01", :version => config.dsl_version, :enabled => true)
        @handler1 = @driver.handlers.new(:filepath => "uc01_execute_processing_for_event.rb", :lineno => 7, :event_type_names => ["event01"])
        @driver.save!
        @event1 = Tengine::Core::Event.new(:event_type_name => :event01, :key => "uuid1", :sender_name => "localhost")
        @event1.save!
      end

      context "イベントの受信待ち状態になる" do
        before do
          # eventmachine と mq の mock を生成
          EM.should_receive(:run).and_yield
          mock_mq = Tengine::Mq::Suite.new(@kernel.config[:event_queue])
          Tengine::Mq::Suite.should_receive(:new).with(@kernel.config[:event_queue]).and_return(mock_mq)
          mock_mq.should_receive(:queue).twice.and_return(@mock_queue)
          # subscribe されていることを検証
          @mock_queue.should_receive(:subscribe).with(:ack => true, :nowait => true)
        end

        it "heartbeatは有効にならない" do
          @kernel.should_not_receive(:enable_heartbeat)
          @kernel.start
        end

        it "heartbeatは有効になる" do
          @kernel.config.should_receive(:heartbeat_enabled?).and_return(true)
          @kernel.should_receive(:enable_heartbeat)
          @kernel.start
        end
      end

      context "発火されたイベントを登録できる" do
        before do
          # eventmachine と mq の mock を生成
          EM.should_receive(:run).and_yield
          mock_mq = Tengine::Mq::Suite.new(@kernel.config[:event_queue])
          Tengine::Mq::Suite.should_receive(:new).with(@kernel.config[:event_queue]).and_return(mock_mq)
          mock_mq.should_receive(:queue).exactly(2).times.and_return(@mock_queue)
          @mock_queue.should_receive(:subscribe).with(:ack => true, :nowait => true).and_yield(@header, :message)

          # subscribe してみる
          @mock_raw_event = mock(:row_event)
          Tengine::Event.should_receive(:parse).with(:message).and_return(@mock_raw_event)

          @header.should_receive(:ack)
        end

        it "confirmation_threshold以下なら登録されたイベントはconfirmedがtrue" do
          @mock_raw_event.stub!(:key).and_return("uniq_key")
          @mock_raw_event.stub!(:sender_name).and_return("localhost")
          @mock_raw_event.stub!(:attributes).and_return(:event_type_name => :foo, :key => "uniq_key", :level => Tengine::Event::LEVELS_INV[:info])
          @mock_raw_event.stub!(:level).and_return(Tengine::Event::LEVELS_INV[:info])
          count = lambda{ Tengine::Core::Event.where(:event_type_name => :foo, :confirmed => true).count }
          expect{ @kernel.start }.should change(count, :call).by(1) # イベントが登録されていることを検証
        end

        it "confirmation_threshold以下なら登録されたイベントはconfirmedがfalse" do
          @mock_raw_event.stub!(:key).and_return("uniq_key")
          @mock_raw_event.stub!(:sender_name).and_return("localhost")
          @mock_raw_event.stub!(:attributes).and_return(:event_type_name => :foo, :key => "uniq_key", :level => Tengine::Event::LEVELS_INV[:warn])
          @mock_raw_event.stub!(:level).and_return(Tengine::Event::LEVELS_INV[:warn])
          count = lambda{ Tengine::Core::Event.where(:event_type_name => :foo, :confirmed => false).count }
          expect{ @kernel.start }.should change(count, :call).by(1) # イベントが登録されていることを検証
        end
      end

      context "イベントストアへの登録有無" do
        it "keyが同じ、sender_nameが異なる場合は、イベントストアへ登録を行わずACKを返却" do
          @header.should_receive(:ack)
          raw_event = Tengine::Event.new(:key => "uuid1", :sender_name => "another_host", :event_type_name => "event1")
          lambda {
            Tengine::Core::Event.create!(raw_event.attributes.update(:confirmed => (raw_event.level <= @kernel.config.confirmation_threshold)))
          }.should raise_error(Mongo::OperationFailure)
          @kernel.process_message(@header, raw_event.to_json)
        end

        it "keyが異なる場合は、イベントストアへ登録を行い、ACKを返却" do
          @header.should_receive(:ack)
          raw_event = Tengine::Event.new(:key => "uuid99", :sender_name => "another_host", :event_type_name => "event1")
          Tengine::Core::Event.should_receive(:create!).and_return(Tengine::Core::Event.new(raw_event.attributes))
          @kernel.process_message(@header, raw_event.to_json)
        end
      end

      context "イベント処理失敗イベントの発火" do
        before do
          # eventmachine と mq の mock を生成
          EM.should_receive(:run).and_yield
          mock_sub_mq = Tengine::Mq::Suite.new(@kernel.config[:event_queue])
          Tengine::Mq::Suite.should_receive(:new).with(@kernel.config[:event_queue]).and_return(mock_sub_mq)
          mock_sub_mq.should_receive(:queue).exactly(2).times.and_return(@mock_queue)
          @mock_queue.should_receive(:subscribe).with(:ack => true, :nowait => true).and_yield(@header, :message)

          # subscribe してみる
          @raw_event = Tengine::Event.new(:key => "uuid1", :sender_name => "localhost", :event_type_name => "event1")
          Tengine::Event.should_receive(:parse).with(:message).and_return(@raw_event)
          @header.should_receive(:ack)
        end

        it "既に登録されているイベントとkey, sender_nameが一致するイベントを受信した場合、発火" do
          # @raw_event = Tengine::Event.new(:key => "uuid1", :sender_name => "localhost", :event_type_name => "event1")

          EM.should_receive(:next_tick).and_yield
          mock_mq = Tengine::Mq::Suite.new(@kernel.config[:event_queue])
          Tengine::Mq::Suite.should_receive(:new).with(@kernel.config[:event_queue]).and_return(mock_mq)
          mock_sender = mock(:sender)
          Tengine::Event::Sender.should_receive(:new).with(mock_mq).and_return(mock_sender)
          mock_sender.should_receive(:fire).with("#{@raw_event.event_type_name}.failed.tengined",
                                            {
                                              :level => Tengine::Event::LEVELS_INV[:error],
                                              :properties => { :original_event => @raw_event }
                                            })
          # @kernel.__send__(:do_save?, @raw_event)
          @kernel.start
          events = Tengine::Core::Event.where(:key => @raw_event.key, :sender_name => @raw_event.sender_name)
          events.count.should == 1
        end
      end

      it "イベント種別に対応したハンドラの処理を実行することができる" do
        # eventmachine と mq の mock を生成
        EM.should_receive(:run).and_yield
        mock_mq = Tengine::Mq::Suite.new(@kernel.config[:event_queue])
        Tengine::Mq::Suite.should_receive(:new).with(@kernel.config[:event_queue]).and_return(mock_mq)
        mock_mq.should_receive(:queue).exactly(2).times.and_return(@mock_queue)
        @mock_queue.should_receive(:subscribe).with(:ack => true, :nowait => true).and_yield(@header, :message)

        # subscribe してみる
        mock_raw_event = mock(:row_event)
        mock_raw_event.stub!(:key).and_return("uuid")
        mock_raw_event.stub!(:sender_name).and_return("localhost")
        mock_raw_event.should_receive(:attributes).and_return(:event_type_name => :event01, :key => "uuid")
        mock_raw_event.stub!(:level).and_return(Tengine::Event::LEVELS_INV[:info])
        Tengine::Event.should_receive(:parse).with(:message).and_return(mock_raw_event)
        # イベントの登録
        Tengine::Core::Event.should_receive(:create!).with(:event_type_name => :event01, :key => "uuid", :confirmed => true).and_return(@event1)

        # ハンドラの実行を検証
        Tengine::Core::HandlerPath.should_receive(:find_handlers).with("event01").and_return([@handler1])
        @handler1.should_receive(:match?).with(@event1).and_return(true)

        @kernel.context.should_receive(:puts).with("handler01")

        @header.should_receive(:ack)

        # 実行
        @kernel.start
      end
    end
  end

  describe :status do
    describe :starting do
      before do
        config = Tengine::Core::Config.new({
            :tengined => {
              :load_path => File.expand_path('../../../../examples/uc01_execute_processing_for_event.rb', File.dirname(__FILE__)),
            },
          })
        @kernel = Tengine::Core::Kernel.new(config)
      end

      it "カーネルのインスタンス生成直後は「初期化済み」の状態を返す" do
        @kernel.status.should == :initialized
      end

      it "起動要求を受け取った直後は「起動中」の状態を返す", :start => true do
        @kernel.should_receive(:bind)
        @kernel.should_receive(:activate)

        @kernel.start
        @kernel.status.should == :starting
      end

      it "内部で使用されるupdate_statusにおかしな値を入れるとArgumentError" do
        expect {
          @kernel.send(:update_status, :invalid_status)
        }.to raise_error(ArgumentError)
      end
    end

    describe :waiting_for_activation do
      before do
        config = Tengine::Core::Config.new({
            :tengined => {
              :load_path => File.expand_path('../../../../examples/uc01_execute_processing_for_event.rb', File.dirname(__FILE__)),
              :wait_activation => true,
              :activation_timeout => 3,
              :activation_dir => File.expand_path('.', File.dirname(__FILE__)),
            },
          })
        @kernel = Tengine::Core::Kernel.new(config)
      end

      it "起動処理が終了した直後に「稼働要求待ち」の状態を返す" do
        @kernel.should_receive(:bind)
        @kernel.should_receive(:wait_for_activation)

        @kernel.start
        @kernel.status.should == :waiting_activation
      end
    end

    describe :running do
      before do
        config = Tengine::Core::Config.new({
            :tengined => {
              :load_path => File.expand_path('../../../../examples/uc01_execute_processing_for_event.rb', File.dirname(__FILE__)),
            },
          })
        @kernel = Tengine::Core::Kernel.new(config)
        @kernel.should_receive(:bind)
      end

      it "稼働要求を受け取った直後では「稼働中」の状態を返す" do
        EM.should_receive(:run).and_yield
        mq = Tengine::Mq::Suite.new(@kernel.config[:event_queue])
        Tengine::Mq::Suite.should_receive(:new).with(@kernel.config[:event_queue]).and_return(mq)
        mock_queue = mock(:queue)
        mq.should_receive(:queue).twice.and_return(mock_queue)
        mock_queue.should_receive(:subscribe).with(:ack => true, :nowait => true)

        @kernel.start
        @kernel.status.should == :running
      end
    end

    describe :stop do
      before do
        @mock_channel = mock(:channel)
        @mock_queue = mock(:queue)
        @mock_consumer = mock(:consumer)
      end

      it "停止要求を受け取った直後では「停止中」および「停止済」の状態を返す(稼働中)" do
        config = Tengine::Core::Config.new({
            :tengined => {
              :load_path => File.expand_path('../../../../examples/uc01_execute_processing_for_event.rb', File.dirname(__FILE__)),
            },
          })
        kernel = Tengine::Core::Kernel.new(config)
        kernel.should_receive(:bind)

        EM.should_receive(:run).and_yield
        mq = Tengine::Mq::Suite.new(kernel.config[:event_queue])
        Tengine::Mq::Suite.should_receive(:new).with(kernel.config[:event_queue]).and_return(mq)
        mq.should_receive(:queue).exactly(3).times.and_return(@mock_queue)
        @mock_queue.should_receive(:subscribe).with(:ack => true, :nowait => true)

        kernel.start
        kernel.status.should == :running

        @mock_queue.should_receive(:default_consumer).and_return(nil)

        kernel.stop
        kernel.status.should == :terminated
      end

      it "停止要求を受け取った直後では「停止中」および「停止済」の状態を返す(稼働要求待ち)" do
        config = Tengine::Core::Config.new({
            :tengined => {
              :load_path => File.expand_path('../../../../examples/uc01_execute_processing_for_event.rb', File.dirname(__FILE__)),
              :wait_activation => true,
              :activation_timeout => 3,
              :activation_dir => File.expand_path('.', File.dirname(__FILE__)),
            },
          })
        kernel = Tengine::Core::Kernel.new(config)
        kernel.should_receive(:bind)

        lambda {
          kernel.start
          # kernel.stop
        }.should raise_error(Tengine::Core::ActivationTimeoutError, "activation file found timeout error.")
        kernel.status.should == :shutting_down
      end
    end
  end

end
