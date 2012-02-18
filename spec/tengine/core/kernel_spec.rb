# -*- coding: utf-8 -*-
require 'spec_helper'
require 'amqp'
require 'eventmachine'

# ログを黙らせたり喋らせたりする
require 'amq/client'
require 'mongoid'
if $DEBUG
  require 'logger'
  AMQP::Session.logger = Tengine.logger = Mongoid.logger = Logger.new(STDERR)
else
  AMQP::Session.logger = Tengine.logger = Mongoid.logger = Tengine::NullLogger.new
end

describe Tengine::Core::Kernel do
  before do
    Tengine::Core::Driver.delete_all
    Tengine::Core::HandlerPath.delete_all
    Tengine::Core::Event.delete_all
  end

  describe :start do
#     describe :bind, "handlerのblockをメモリ上で保持" do
#       before do
#         config = Tengine::Core::Config::Core.new({
#             :tengined => {
#               :load_path => File.expand_path('../../../examples/uc01_execute_processing_for_event.rb', File.dirname(__FILE__)),
#             },
#           })
#         @kernel = Tengine::Core::Kernel.new(config)
#         @driver = Tengine::Core::Driver.new(:name => "driver01", :version => config.dsl_version, :enabled => true)
#         @handler1 = @driver.handlers.new(:filepath => "uc01_execute_processing_for_event.rb", :lineno => 7, :event_type_names => ["event01"])
#         @driver.save!
#       end

#       it "event_type_nameからblockを検索することができる" do
#         @kernel.bind
#         @kernel.context.__block_for__(@handler1).should_not be_nil
#       end

#       context "拡張モジュールあり" do
#         before(:all) do
#           @ext_mod1 = Module.new{}
#           @ext_mod1.instance_eval do
#             def dsl_binder; self; end
#           end
#           Tengine.plugins.add(@ext_mod1)
#         end

#         it "Kernel#contextに拡張モジュールがextendされる" do
#           @kernel.bind
#           @kernel.context.__block_for__(@handler1).should_not be_nil
#           @kernel.context.should be_a(Tengine::Core::DslBinder)
#           @kernel.context.should be_a(@ext_mod1)
#         end
#       end

#     end

    describe :wait_for_activation, "activate待ち" do
      before do
        config = Tengine::Core::Config::Core.new({
            :tengined => {
              :load_path => File.expand_path('../../../examples/uc01_execute_processing_for_event.rb', File.dirname(__FILE__)),
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

        config = Tengine::Core::Config::Core.new({
            :tengined => {
              :load_path => File.expand_path('../../../examples/uc01_execute_processing_for_event.rb', File.dirname(__FILE__)),
              :wait_activation => false,
              :confirmation_threshold => 'info'
            },
            :heartbeat => {
              :core => {
                :interval => 1024,
                :expire => 32768,
              },
            },
          })
        @kernel = Tengine::Core::Kernel.new(config)
        @driver = Tengine::Core::Driver.new(
          :name => "driver01", :version => config.dsl_version, :enabled => true)
        @handler1 = @driver.handlers.new(
          :filepath => "uc01_execute_processing_for_event.rb", :lineno => 7, :event_type_names => ["event01"])
        @driver.save!
        @event1 = Tengine::Core::Event.new(:event_type_name => :event01, :key => "uuid1", :sender_name => "localhost")
        @event1.save!
      end

      context "イベントの受信待ち状態になる" do
        before do
          # eventmachine と mq の mock を生成
          mock_mq = mock("mq")
          mock_sender = mock("sender")
          @kernel.stub(:mq).and_return(mock_mq)
          @kernel.stub(:sender).and_return(mock_sender)
          mock_sender.stub(:fire)
          mock_mq.stub(:initiate_termination).and_yield
          mock_mq.stub(:unsubscribe).and_yield
          mock_mq.stub(:stop).and_yield
          mock_mq.stub(:add_hook)
          mock_mq.stub(:subscribe).with(nil).with(:ack => true, :nowait => false, :confirm => an_instance_of(Proc)) do |h, b|
            h[:confirm].yield(mock("confirm-ok"))
            #b.yield(@header, :message)
          end
          # subscribe されていることを検証
          mock_mq.should_receive(:subscribe).with(:ack => true, :nowait => false, :confirm => an_instance_of(Proc))
        end

        it "heartbeatは有効にならない" do
          @kernel.config[:heartbeat][:core][:interval] = -1
          @kernel.should_receive(:setup_mq_connection)
          sender = mock(:sender)
          @kernel.stub(:sender).and_return(sender)
          sender.stub(:fire).with("finished.process.core.tengine", an_instance_of(Hash)).and_yield
          @kernel.start
        end

        it "heartbeatは有効になる" do
          @kernel.config[:heartbeat][:core][:interval] = 65535
          EM.should_receive(:add_periodic_timer).with(65535).and_yield
          sender = mock(:sender)
          @kernel.stub(:sender).and_return(sender)
          sender.stub(:fire).with("finished.process.core.tengine", an_instance_of(Hash)).and_yield
          sender.stub(:fire).with("core.heartbeat.tengine", an_instance_of(Hash))
          @kernel.start do
            @kernel.stop
          end
        end

        it "heartbeatが送られる" do
          @kernel.should_receive(:setup_mq_connection)
          EM.should_receive(:add_periodic_timer).with(1024).and_yield
          mock_sender = mock(:sender)
          @kernel.stub(:sender).and_return(mock_sender)
          mock_sender.stub(:fire).with("finished.process.core.tengine", an_instance_of(Hash)).and_yield
          mock_sender.stub(:fire).with("core.heartbeat.tengine", an_instance_of(Hash))
          @kernel.start
        end
      end

      context "発火されたイベントを登録できる" do
        before do
          # eventmachine と mq の mock を生成
          mock_mq = mock("mq")
          mock_sender = mock("sender")
          @kernel.stub(:mq).and_return(mock_mq)
          @kernel.stub(:sender).and_return(mock_sender)
          mock_sender.stub(:fire)
          mock_mq.stub(:initiate_termination).and_yield
          mock_mq.stub(:unsubscribe).and_yield
          mock_mq.stub(:stop).and_yield
          mock_mq.stub(:add_hook)
          mock_mq.stub(:subscribe).with(nil).with(:ack => true, :nowait => false, :confirm => an_instance_of(Proc)) do |h, b|
            h[:confirm].yield(mock("confirm-ok"))
            b.yield(@header, :message)
          end

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
          @mock_raw_event.stub!(:event_type_name).and_return("foo")
          count = lambda{ Tengine::Core::Event.where(:event_type_name => :foo, :confirmed => true).count }
          expect{ @kernel.start { @kernel.stop } }.should change(count, :call).by(1) # イベントが登録されていることを検証
        end

        it "confirmation_threshold以下なら登録されたイベントはconfirmedがfalse" do
          @mock_raw_event.stub!(:key).and_return("uniq_key")
          @mock_raw_event.stub!(:sender_name).and_return("localhost")
          @mock_raw_event.stub!(:attributes).and_return(:event_type_name => :foo, :key => "uniq_key", :level => Tengine::Event::LEVELS_INV[:warn])
          @mock_raw_event.stub!(:level).and_return(Tengine::Event::LEVELS_INV[:warn])
          @mock_raw_event.stub!(:event_type_name).and_return("foo")
          count = lambda{ Tengine::Core::Event.where(:event_type_name => :foo, :confirmed => false).count }
          @kernel.should_receive(:setup_mq_connection)
          expect{ @kernel.start }.should change(count, :call).by(1) # イベントが登録されていることを検証
        end
      end

      context "イベントストアへの登録有無" do
        it "不正なフォーマットのメッセージの場合、イベントストアへ登録を行わずACKを返却" do
          @header.should_receive(:ack)
          @kernel.process_message(@header, "invalid format message").should_not be_true
        end

        it "https://www.pivotaltracker.com/story/show/22698533" do
          ev = Tengine::Event.new  :key => "2498e870-11cd-012f-f8c0-48bcc89f84e1", :source_name => "localhost/8110", :sender_name => "localhost/8110", :level => 2, :occurred_at => Time.now, :properties => {}, :event_type_name => ""
          @header.should_receive(:ack)
          @kernel.process_message(@header, ev.to_json).should_not be_true
        end

        it "keyがnilのイベント場合、イベントストアへ登録を行わずACKを返却" do
          raw_event = Tengine::Event.new(:key => "", :sender_name => "another_host", :event_type_name => "event1")
          @header.should_receive(:ack)
          @kernel.process_message(@header, raw_event.to_json).should_not be_true
        end

        it "keyが同じ、sender_nameが異なる場合は、イベントストアへ登録を行わずACKを返却" do
          @header.should_receive(:ack)
          raw_event = Tengine::Event.new(:key => "uuid1", :sender_name => "another_host", :event_type_name => "event1")
          lambda {
            Tengine::Core::Event.create!(raw_event.attributes.update(:confirmed => (raw_event.level <= @kernel.config.confirmation_threshold)))
          }.should raise_error(Mongo::OperationFailure)
          @kernel.process_message(@header, raw_event.to_json).should_not be_true
        end

        it "keyが異なる場合は、イベントストアへ登録を行い、ACKを返却" do
          @header.should_receive(:ack)
          raw_event = Tengine::Event.new(:key => "uuid99", :sender_name => "another_host", :event_type_name => "event1")
          Tengine::Core::Event.should_receive(:create!).and_return(Tengine::Core::Event.new(raw_event.attributes))
          @kernel.process_message(@header, raw_event.to_json).should be_true
        end
      end

      context "イベント処理失敗イベントの発火" do
        before do
          # eventmachine と mq の mock を生成
          mock_mq = mock("mq")
          @kernel.stub(:mq).and_return(mock_mq)
          mock_mq.stub(:initiate_termination).and_yield
          mock_mq.stub(:unsubscribe).and_yield
          mock_mq.stub(:stop).and_yield
          mock_mq.stub(:add_hook)
          mock_mq.stub(:subscribe).with(nil).with(:ack => true, :nowait => false, :confirm => an_instance_of(Proc)) do |h, b|
            h[:confirm].yield(mock("confirm-ok"))
            b.yield(@header, :message)
          end

          # subscribe してみる
          @raw_event = Tengine::Event.new(:key => "uuid1", :sender_name => "localhost", :event_type_name => "event1")
          Tengine::Event.should_receive(:parse).with(:message).and_return(@raw_event)
          @header.should_receive(:ack)
        end

        it "既に登録されているイベントとkey, sender_nameが一致するイベントを受信した場合、発火" do
          mock_sender = mock(:sender)
          Tengine::Event::Sender.should_receive(:new).with(@kernel.mq).and_return(mock_sender)
          mock_sender.should_receive(:default_keep_connection=).with(true)
          mock_sender.should_receive(:fire).with("#{@raw_event.event_type_name}.failed.tengined",
                                            {
                                              :level => Tengine::Event::LEVELS_INV[:error],
                                              :properties => { :original_event => @raw_event }
                                            })
          mock_sender.stub(:fire).with("finished.process.core.tengine", an_instance_of(Hash)).and_yield
          @kernel.start { @kernel.stop }
          events = Tengine::Core::Event.where(:key => @raw_event.key, :sender_name => @raw_event.sender_name)
          events.count.should == 1
        end
      end

      it "イベント種別に対応したハンドラの処理を実行することができる" do
        # eventmachine と mq の mock を生成
        mock_mq = mock("mq")
        mock_sender = mock("sender")
        @kernel.stub(:mq).and_return(mock_mq)
        @kernel.stub(:sender).and_return(mock_sender)
        mock_sender.stub(:fire)
        mock_mq.stub(:initiate_termination).and_yield
        mock_mq.stub(:unsubscribe).and_yield
        mock_mq.stub(:stop).and_yield
        mock_mq.stub(:add_hook)
        mock_mq.stub(:subscribe).with(nil).with(:ack => true, :nowait => false, :confirm => an_instance_of(Proc)) do |h, b|
          h[:confirm].yield(mock("confirm-ok"))
          b.yield(@header, :message)
        end

        # subscribe してみる
        mock_raw_event = mock(:row_event)
        mock_raw_event.stub!(:key).and_return("uuid")
        mock_raw_event.stub!(:sender_name).and_return("localhost")
        mock_raw_event.should_receive(:attributes).and_return(:event_type_name => :event01, :key => "uuid")
        mock_raw_event.stub!(:level).and_return(Tengine::Event::LEVELS_INV[:info])
        mock_raw_event.stub!(:event_type_name).and_return("event01")
        Tengine::Event.should_receive(:parse).with(:message).and_return(mock_raw_event)
        # イベントの登録
        Tengine::Core::Event.should_receive(:create!).with(:event_type_name => :event01, :key => "uuid", :confirmed => true).and_return(@event1)

        # ハンドラの実行を検証
        Tengine::Core::HandlerPath.should_receive(:find_handlers).with("event01").and_return([@handler1])
        @handler1.should_receive(:match?).with(@event1).and_return(true)

        # 仕様変更のためイベントハンドラの処理を確認するのは一旦コメントアウトしました
        # @kernel.context.should_receive(:puts).with("handler01")

        @header.should_receive(:ack)

        # 実行
        @kernel.start
      end

      context "*.failed.tengine" do
        before do
          @uuid = ::UUID.new
          @header.stub(:ack)
          @sender = mock(:sender)
          @kernel.stub(:sender).and_return(@sender)
          @sender.should_not_receive(:fire)
        end

        context "正常系" do
          it "メッセージストアに保存" do
            e = Tengine::Event.new key: @uuid.generate, event_type_name: "something.failed.tengine"

            @kernel.process_message @header, e.to_json

            Tengine::Core::Event.where(key: e.key).count.should == 1
            Tengine::Core::Event.where(key: e.key).first.event_type_name.should =~ /failed\.tengine$/
          end
        end

        context "異常系" do
          it "無限地獄の回避" do
            Tengine::Core::Event.stub(:create!).and_raise(Mongo::OperationFailure.new)
            e = Tengine::Event.new key: @uuid.generate, event_type_name: "something.failed.tengine"

            @kernel.process_message @header, e.to_json
          end
        end
      end

      context "heartbeat" do
        before do
          @uuid = ::UUID.new
          @header.stub(:ack)
          @sender = mock(:sender)
          @kernel.stub(:sender).and_return(@sender)
        end

        shared_examples "generic heartbeats" do
          context "正常系" do
            context "初回" do
              before do
                @u = @uuid.generate
                Tengine::Core::Event.where(key: @u).delete_all
              end
              it "beatは保存される" do
                @kernel.process_message(@header, Tengine::Event.new(key: @u, event_type_name: "#{kind}.heartbeat.tengine").to_json).should be_true
                Tengine::Core::Event.where(key: @u).count.should == 1
                Tengine::Core::Event.where(key: @u).first.event_type_name.should =~ /^#{kind}/
              end

              it "finishedは保存される" do
                @kernel.process_message(@header, Tengine::Event.new(key: @u, event_type_name: "finished.process.#{kind}.tengine").to_json).should be_true
                Tengine::Core::Event.where(key: @u).count.should == 1
                Tengine::Core::Event.where(key: @u).first.event_type_name.should =~ /^finished/
              end

              it "expiredは保存される" do
                @kernel.process_message(@header, Tengine::Event.new(key: @u, event_type_name: "expired.#{kind}.heartbeat.tengine").to_json).should be_true
                Tengine::Core::Event.where(key: @u).count.should == 1
                Tengine::Core::Event.where(key: @u).first.event_type_name.should =~ /^expired/
              end
            end

            it "beat -> beat -> beat" do
              e = Tengine::Event.new key: @uuid.generate, event_type_name: "#{kind}.heartbeat.tengine"

              @kernel.process_message @header, e.to_json
              @kernel.process_message @header, e.to_json
              @kernel.process_message @header, e.to_json

              Tengine::Core::Event.where(key: e.key).count.should == 1
              Tengine::Core::Event.where(key: e.key).first.event_type_name.should =~ /^#{kind}/
            end

            it "beat -> finished (finishedが勝つ)" do
              u = @uuid.generate
              @kernel.process_message @header, Tengine::Event.new(key: u, event_type_name: "#{kind}.heartbeat.tengine").to_json
              @kernel.process_message @header, Tengine::Event.new(key: u, event_type_name: "finished.process.#{kind}.tengine").to_json

              Tengine::Core::Event.where(key: u).count.should == 1
              Tengine::Core::Event.where(key: u).first.event_type_name.should =~ /finished/
            end

            it "beat -> expired (expiredが勝つ)" do
              u = @uuid.generate
              @kernel.process_message @header, Tengine::Event.new(key: u, event_type_name: "#{kind}.heartbeat.tengine").to_json
              @kernel.process_message @header, Tengine::Event.new(key: u, event_type_name: "expired.#{kind}.heartbeat.tengine").to_json

              Tengine::Core::Event.where(key: u).count.should == 1
              Tengine::Core::Event.where(key: u).first.event_type_name.should =~ /expired/
            end

            it "beat -> finish -> expired (expiredが勝つ)" do
              u = @uuid.generate
              @kernel.process_message @header, Tengine::Event.new(key: u, event_type_name: "#{kind}.heartbeat.tengine").to_json
              @kernel.process_message @header, Tengine::Event.new(key: u, event_type_name: "finished.process.#{kind}.tengine").to_json
              @kernel.process_message @header, Tengine::Event.new(key: u, event_type_name: "expired.#{kind}.heartbeat.tengine").to_json

              Tengine::Core::Event.where(key: u).count.should == 1
              Tengine::Core::Event.where(key: u).first.event_type_name.should =~ /expired/
            end

            it "finished -> beat (finishedが勝つ)" do
              u = @uuid.generate
              @kernel.process_message @header, Tengine::Event.new(key: u, event_type_name: "finished.process.#{kind}.tengine").to_json
              @kernel.process_message @header, Tengine::Event.new(key: u, event_type_name: "#{kind}.heartbeat.tengine").to_json

              Tengine::Core::Event.where(key: u).count.should == 1
              Tengine::Core::Event.where(key: u).first.event_type_name.should =~ /finished/
            end

            it "finished -> finished (上書き)" do
              e = Tengine::Event.new key: @uuid.generate, event_type_name: "finished.process.#{kind}.tengine"

              @kernel.process_message @header, e.to_json
              @kernel.process_message @header, e.to_json

              Tengine::Core::Event.where(key: e.key).count.should == 1
              Tengine::Core::Event.where(key: e.key).first.event_type_name.should =~ /finished/
            end

            it "finished -> expired (expiredが勝つ)" do
              u = @uuid.generate
              @kernel.process_message @header, Tengine::Event.new(key: u, event_type_name: "finished.process.#{kind}.tengine").to_json
              @kernel.process_message @header, Tengine::Event.new(key: u, event_type_name: "expired.#{kind}.heartbeat.tengine").to_json

              Tengine::Core::Event.where(key: u).count.should == 1
              Tengine::Core::Event.where(key: u).first.event_type_name.should =~ /expired/
            end

            it "expired -> beat (expiredが勝つ)" do
              u = @uuid.generate
              @kernel.process_message @header, Tengine::Event.new(key: u, event_type_name: "expired.#{kind}.heartbeat.tengine").to_json
              @kernel.process_message @header, Tengine::Event.new(key: u, event_type_name: "#{kind}.heartbeat.tengine").to_json

              Tengine::Core::Event.where(key: u).count.should == 1
              Tengine::Core::Event.where(key: u).first.event_type_name.should =~ /expired/
            end

            it "expired -> finished (expiredが勝つ)" do
              u = @uuid.generate
              @kernel.process_message @header, Tengine::Event.new(key: u, event_type_name: "expired.#{kind}.heartbeat.tengine").to_json
              @kernel.process_message @header, Tengine::Event.new(key: u, event_type_name: "finished.process.#{kind}.tengine").to_json

              Tengine::Core::Event.where(key: u).count.should == 1
              Tengine::Core::Event.where(key: u).first.event_type_name.should =~ /expired/
            end

            it "expired -> expired (上書き)" do
              e = Tengine::Event.new key: @uuid.generate, event_type_name: "expired.#{kind}.heartbeat.tengine"

              @kernel.process_message @header, e.to_json
              @kernel.process_message @header, e.to_json

              Tengine::Core::Event.where(key: e.key).count.should == 1
              Tengine::Core::Event.where(key: e.key).first.event_type_name.should =~ /expired/
            end

            it "finished -> finished (失敗する)" do
              EM.stub(:next_tick).and_yield
              e = Tengine::Event.new key: @uuid.generate, event_type_name: "finished.process.#{kind}.tengine"
              @sender.should_receive(:fire).with("finished.process.#{kind}.tengine.failed.tengined", an_instance_of(Hash))

              @kernel.process_message @header, e.to_json
              @kernel.process_message @header, e.to_json

              Tengine::Core::Event.where(key: e.key).count.should == 1
              Tengine::Core::Event.where(key: e.key).first.event_type_name.should =~ /finished/
            end
          end

          context "異常系" do
            ['"#{kind}.heartbeat.tengine"',
             '"finished.process.#{kind}.tengine"',
             '"expired.#{kind}.heartbeat.tengine"'
            ].each do |name|
              context name do
                it "Mongo::OperationFailureの場合、failed eventを連鎖" do
                  @sender.stub(:fire).with("#{kind}.heartbeat.tengine.failed.tengine", an_instance_of(Hash))
                  Tengine::Core::Event.stub(:create!).and_raise(Mongo::OperationFailure.new)
                  @kernel.stub(:upsert).and_raise Mongo::OperationFailure

                  @kernel.process_message @header, Tengine::Event.new(key: @uuid.generate, event_type_name: eval(name)).to_json
                end

                it "Mongoid::Errors::Validationの場合、failed eventを連鎖" do
                  x = Tengine::Core::Event.new
                  x.valid? # false
                  @sender.stub(:fire).with("#{kind}.heartbeat.tengine.failed.tengine", an_instance_of(Hash))
                  Tengine::Core::Event.stub(:create!).and_raise(Mongoid::Errors::Validations.new(x))
                  @kernel.stub(:upsert).and_raise Mongoid::Errors::Validations.new(x)

                  @kernel.process_message @header, Tengine::Event.new(key: @uuid.generate, event_type_name: eval(name)).to_json
                end

                it "その他の場合、例外を外に伝播しない" do
                  Tengine::Core::Event.stub(:find_or_create_by_key_then_update_with_block).and_raise StandardError
                  expect do
                    @kernel.process_message @header, Tengine::Event.new(key: @uuid.generate, event_type_name: eval(name)).to_json
                  end.to_not raise_exception(StandardError)
                  @kernel.process_message @header, Tengine::Event.new(key: @uuid.generate, event_type_name: eval(name)).to_json
                end
              end
            end
          end
        end

        describe "job heartbeat" do
          let(:kind) {"job"}
          it_behaves_like "generic heartbeats"
        end

        describe "core heartbeat" do
          let(:kind) {"core"}
          it_behaves_like "generic heartbeats"
        end

        describe "heartbeat watcher's heartbeat" do
          let(:kind) {"hbw"}
          it_behaves_like "generic heartbeats"
        end

        describe "atd heartbeat" do
          let(:kind) {"atd"}
          it_behaves_like "generic heartbeats"
        end
      end

      describe "schedule" do
        it "tenginedが調停する" do
          @header.stub(:ack)
          n = "alert.execution.job.tengine"
          s = "test test"
          e = Tengine::Event.new event_type_name: n, source_name: s

          @kernel.process_message @header, e.to_json
          @kernel.process_message @header, e.to_json
          @kernel.process_message @header, e.to_json

          Tengine::Core::Event.where(event_type_name: n, source_name: s).count.should == 1
        end

        it "tenginedが調停する #2" do
          @header.stub(:ack)
          n = "alert.execution.job.tengine"
          s = "test test"
          e = Tengine::Event.new event_type_name: n, source_name: s, key: "k1"
          f = Tengine::Event.new event_type_name: n, source_name: s, key: "k2"
          g = Tengine::Event.new event_type_name: n, source_name: s, key: "k3"

          @kernel.process_message @header, e.to_json
          @kernel.process_message @header, f.to_json
          @kernel.process_message @header, g.to_json

          Tengine::Core::Event.where(event_type_name: n, source_name: s).count.should == 1
        end
      end
    end
  end

  describe :setup_mq_connection do
    if RUBY_VERSION >= "1.9.2"
      before do
        EM.instance_eval do
          @timers.each {|i| EM.cancel_timer i } if @timers
          @next_tick_queue = nil
        end
        trigger
        config = Tengine::Core::Config::Core.new({
          :tengined => {
            :load_path => File.expand_path('../../../examples/uc01_execute_processing_for_event.rb', File.dirname(__FILE__)),
          },
          :event_queue => { :connection => { :port => @port } } 
        })
        @kernel = Tengine::Core::Kernel.new(config)
      end

      let(:rabbitmq) do
        ret = nil
        ENV["PATH"].split(/:/).find do |dir|
          Dir.glob("#{dir}/rabbitmq-server") do |path|
            if File.executable?(path)
              ret = path
              break
            end
          end
        end

        pending "rabbitmq が見つかりません" unless ret
        ret
      end

      def trigger port = rand(32768)
        require 'tmpdir'
        @dir = Dir.mktmpdir
        # 指定したポートはもう使われているかもしれないので、その際は
        # rabbitmqが起動に失敗するので、何回かポートを変えて試す。
        n = 0
        begin
          envp = {
            "RABBITMQ_NODENAME"        => "rspec",
            "RABBITMQ_NODE_PORT"       => port.to_s,
            "RABBITMQ_NODE_IP_ADDRESS" => "auto",
            "RABBITMQ_MNESIA_BASE"     => @dir.to_s,
            "RABBITMQ_LOG_BASE"        => @dir.to_s,
          }
          @pid = Process.spawn(envp, rabbitmq, :chdir => @dir, :in => :close, :out => '/dev/null', :err => '/dev/null')
          x = Time.now
          while Time.now < x + 64 do # まあこんくらい待てばいいでしょ
            sleep 0.1
            Process.waitpid2(@pid, Process::WNOHANG)
            Process.kill 0, @pid
            # netstat -an は Linux / BSD ともに有効
            # どちらかに限ればもう少し効率的な探し方はある。たとえば Linux 限定でよければ netstat -lnt ...
            y = `netstat -an | fgrep LISTEN | fgrep #{port}`
            if y.lines.to_a.size > 1
              @port = port
              return
            end
          end
          pending "failed to invoke rabbitmq in 16 secs."
        rescue Errno::ECHILD, Errno::ESRCH
          pending "10 attempts to invoke rabbitmq failed." if (n += 1) > 10
          port = rand(32768)
          retry
        end
      end

      def finish
        if @pid
          begin
            Process.kill "INT", @pid
            Process.waitpid @pid
          rescue Errno::ECHILD, Errno::ESRCH
          ensure
            require 'fileutils'
            FileUtils.remove_entry_secure @dir, :force
          end
        end
      end

      after do
        finish
      end

      it "MQ接続時にエラーなどのイベントハンドリングを行います" do
        EM.run do
          mq = @kernel.mq

          @kernel.setup_mq_connection

          # ここではイベント発生時の振る舞いもチェックします
          @kernel.subscribe_queue do
            Tengine::Core.stderr_logger.should_receive(:warn).with('mq.connection.on_tcp_connection_loss.').at_least(1).times
            finish
            EM.add_timer(1) do
              Tengine::Core.stderr_logger.should_receive(:info).with('mq.connection.after_recovery: recovered successfully.')
              EM.defer(
                lambda { trigger @port; sleep 2; true },
                lambda do |a|
                  Tengine::Core.stderr_logger.should_receive(:error).with('mq.channel.on_error channel_close: "channel close reason object"')
                  mq.channel.exec_callback_once_yielding_self(:error, "channel close reason object")

                  Tengine::Core.stderr_logger.should_receive(:error).with('mq.connection.on_error connection_close: "connection close reason object"')
                  mq.connection.exec_callback_yielding_self(:error, "connection close reason object")

                  EM.next_tick do
                    mq.stop
                  end
                end
              )
            end
          end
        end
      end
    end
  end

  describe :status do
    describe :starting do
      before do
        config = Tengine::Core::Config::Core.new({
            :tengined => {
              :load_path => File.expand_path('../../../examples/uc01_execute_processing_for_event.rb', File.dirname(__FILE__)),
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
        config = Tengine::Core::Config::Core.new({
            :tengined => {
              :load_path => File.expand_path('../../../examples/uc01_execute_processing_for_event.rb', File.dirname(__FILE__)),
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
        config = Tengine::Core::Config::Core.new({
            :tengined => {
              :load_path => File.expand_path('../../../examples/uc01_execute_processing_for_event.rb', File.dirname(__FILE__)),
            },
          })
        @kernel = Tengine::Core::Kernel.new(config)
        @kernel.should_receive(:bind)
      end

      it "稼働要求を受け取った直後では「稼働中」の状態を返す" do
        mock_mq = mock("mq")
        mock_sender = mock("sender")
        @kernel.stub(:mq).and_return(mock_mq)
        @kernel.stub(:sender).and_return(mock_sender)
        mock_sender.stub(:fire).and_yield
        mock_mq.stub(:initiate_termination).and_yield
        mock_mq.stub(:unsubscribe).and_yield
        mock_mq.stub(:stop).and_yield
        mock_mq.stub(:add_hook)
        mock_mq.stub(:subscribe).with(nil).with(:ack => true, :nowait => false, :confirm => an_instance_of(Proc)) do |h, b|
          h[:confirm].yield(mock("confirm-ok"))
        end

        @kernel.should_receive(:setup_mq_connection)
        @kernel.start do
          @kernel.status.should == :running
          @kernel.stop
        end
      end
    end

    describe :stop do
      it "停止要求を受け取った直後では「停止中」および「停止済」の状態を返す(稼働中)" do
        config = Tengine::Core::Config::Core.new({
            :tengined => {
              :load_path => File.expand_path('../../../examples/uc01_execute_processing_for_event.rb', File.dirname(__FILE__)),
            },
          })
        kernel = Tengine::Core::Kernel.new(config)
        kernel.should_receive(:bind)

        mock_mq = mock("mq")
        mock_sender = mock("sender")
        kernel.stub(:mq).and_return(mock_mq)
        kernel.stub(:sender).and_return(mock_sender)
        mock_sender.stub(:fire).and_yield
        mock_mq.stub(:initiate_termination).and_yield
        mock_mq.stub(:unsubscribe).and_yield
        mock_mq.stub(:stop).and_yield
        mock_mq.stub(:add_hook)
        mock_mq.stub(:subscribe).with(nil).with(:ack => true, :nowait => false, :confirm => an_instance_of(Proc)) do |h, b|
          h[:confirm].yield(mock("confirm-ok"))
        end

        kernel.start do
          kernel.status.should == :running

          kernel.stop do
            kernel.status.should == :terminated
          end
        end
      end

      it "停止要求を受け取った直後では「停止中」および「停止済」の状態を返す(稼働要求待ち)" do
        config = Tengine::Core::Config::Core.new({
            :tengined => {
              :load_path => File.expand_path('../../../examples/uc01_execute_processing_for_event.rb', File.dirname(__FILE__)),
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

      it "heartbeatの停止" do
        kernel = Tengine::Core::Kernel.new(Tengine::Core::Config::Core.new({
            :tengined => {
              :load_path => File.expand_path('../../../examples/uc01_execute_processing_for_event.rb', File.dirname(__FILE__)),
              :wait_activation => true,
              :activation_timeout => 3,
              :activation_dir => File.expand_path('.', File.dirname(__FILE__)),
            },
          }))
        kernel.instance_eval do
          @status = :running
          @heartbeat_timer = true
        end
        mock_mq = mock("mq")
        kernel.stub(:mq).and_return(mock_mq)
        mock_mq.stub(:initiate_termination).and_yield
        mock_mq.stub(:unsubscribe).and_yield
        mock_mq.stub(:stop).and_yield
        mock_mq.stub(:add_hook)
        mock_mq.stub(:subscribe).with(nil).with(:ack => true, :nowait => false, :confirm => an_instance_of(Proc)) do |h, b|
          h[:confirm].yield(mock("confirm-ok"))
        end
        sender = mock(:sender)
        kernel.stub(:sender).and_return(sender)
        
        EM.should_receive(:cancel_timer)
        sender.should_receive(:fire).with("finished.process.core.tengine", an_instance_of(Hash))

        kernel.stop
      end
    end
  end

end
