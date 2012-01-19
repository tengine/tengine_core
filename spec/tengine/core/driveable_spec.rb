# -*- coding: utf-8 -*-
require 'spec_helper'

describe Tengine::Core::Driveable do

  describe :handling_by_instance_method do
    before do
      Tengine::Core::Setting.delete_all
      Tengine::Core::Setting.create!(:name => "dsl_version", :value => "123")
      Tengine::Core::Driver.delete_all
      Tengine::Core::HandlerPath.delete_all
    end

    def driveable_test_class_index
      $dtcindex ||= 0
    end

    def define_driveable_test_class
      $dtcindex ||= 0
      $dtcindex += 1
      @klass = Class.new
      Object.const_set(:"DriveableTestClass#{$dtcindex}", @klass)
      @klass.module_eval do
        include Tengine::Core::Driveable

        on:event01
        def foo # 引数なしでもOK
          STDOUT.puts "#{self.class.name}#foo"
        end

        on :event02, :event3 # 複数のイベント種別をハンドリング
        def bar(with_event) # 引数ありでもOK
          STDOUT.puts "#{self.class.name}#foo with event"
        end

        class << self # クラスメソッドの定義
          on:event04
          def baz # 引数なしでもOK
            STDOUT.puts "#{self.name}#baz"
          end
        end

        on :event05, :event6 # 複数のイベント種別をハンドリング
        def self.hoge(with_event) # 引数ありでもOK
          STDOUT.puts "#{self.name}#hoge with event"
        end
      end
    end

    context "[Bug]tenginedのデプロイコマンド bundle exec cap deploy:start を実行すると起動しないことがある" do
      context "nameとversionが同じものを２度書きもうとして" do
        before do
          @klass1, @klass2 = Class.new, Class.new
        end

        it "nameとversionのuniquenessバリデーションにひっかかる場合にはMongoid::Errors::Validationsをraiseしない" do
          Tengine::Core::Setting.should_receive(:dsl_version).exactly(3).times.and_return("123")
          @klass1.should_receive(:driver).and_return(nil)
          @klass1.should_receive(:driver_name).and_return("foo")
          @klass1.module_eval { include Tengine::Core::Driveable }

          @klass2.should_receive(:driver).and_return(nil)
          @klass2.should_receive(:driver_name).exactly(2).times.and_return("foo")
          @klass2.module_eval { include Tengine::Core::Driveable }
        end

        it "versionのformatバリデーションにひっかかる場合にはMongoid::Errors::Validationsをraiseする" do
          [@klass1, @klass2].each do |k|
            Tengine::Core::Setting.should_receive(:dsl_version).and_return("123")
            k.should_receive(:driver).and_return(nil)
            k.should_receive(:driver_name).and_return("123")
            expect { k.module_eval { include Tengine::Core::Driveable } }.to raise_error
          end
        end

        it "バリデーションで引っかからずにユニークインデックスの一意キー制約違反で落ちる場合にはMongo::OperationFailureをraiseしない" do
          # バリデーションのチェックをくぐり抜けてインサートを行わせるため
          Mongoid::Persistence::Operations::Insert.class_eval do
            def persist
              prepare do |doc|
                Fiber.yield
                collection.insert(doc.as_document, options)
                Mongoid::IdentityMap.set(doc)
              end
            end
          end

          f1 = Fiber.new {
            Tengine::Core::Setting.should_receive(:dsl_version).and_return("123")
            @klass1.should_receive(:driver).and_return(nil)
            @klass1.should_receive(:driver_name).and_return("bar")
            @klass1.module_eval { include Tengine::Core::Driveable }
          }
          f1.resume

          f2 = Fiber.new {
            Tengine::Core::Setting.should_receive(:dsl_version).exactly(2).times.and_return("123")
            @klass2.should_receive(:driver).and_return(nil)
            @klass2.should_receive(:driver_name).exactly(2).times.and_return("bar")
            @klass2.module_eval { include Tengine::Core::Driveable }
          }
          f2.resume
          f1.resume
          f2.resume
          f1.resume
          f2.resume

          # 元に戻しておく
          Mongoid::Persistence::Operations::Insert.class_eval do
            def persist
              prepare do |doc|
                collection.insert(doc.as_document, options)
                Mongoid::IdentityMap.set(doc)
              end
            end
          end
        end
      end
    end

    it "クラスを定義するファイルをloadするとドライバが登録されます" do
      expect{
        expect{
          # load(File.expand_path('driveable_spec/driveable_test_class.rb', File.dirname(__FILE__)))
          define_driveable_test_class
        }.to change(Tengine::Core::Driver, :count).by(1)
      }.to change(Tengine::Core::HandlerPath, :count).by(6)
    end

    context "すでにロードされている場合" do
      before do
        driver = Tengine::Core::Driver.new(
          :name => "DriveableTestClass#{driveable_test_class_index + 1}",
          :version => Tengine::Core::Setting.dsl_version,
          :target_class_name => "DriveableTestClass#{driveable_test_class_index + 1}"
          )
        options = {:filepath => __FILE__, :lineno => __LINE__}
        handler1 = driver.handlers.new({:target_method_name => 'foo' , :target_instantiation_key => :instance_method, :event_type_names => ['event01']}.update(options))
        handler2 = driver.handlers.new({:target_method_name => 'bar' , :target_instantiation_key => :instance_method, :event_type_names => ['event02', 'event03']}.update(options))
        handler3 = driver.handlers.new({:target_method_name => 'baz' , :target_instantiation_key => :static         , :event_type_names => ['event04']}.update(options))
        handler4 = driver.handlers.new({:target_method_name => 'hoge', :target_instantiation_key => :static         , :event_type_names => ['event05', 'event06']}.update(options))
        driver.save!
        driver.handler_paths.create!(:handler_id => handler1.id, :event_type_name => "event01")
        driver.handler_paths.create!(:handler_id => handler2.id, :event_type_name => "event02")
        driver.handler_paths.create!(:handler_id => handler2.id, :event_type_name => "event03")
        driver.handler_paths.create!(:handler_id => handler3.id, :event_type_name => "event04")
        driver.handler_paths.create!(:handler_id => handler4.id, :event_type_name => "event05")
        driver.handler_paths.create!(:handler_id => handler4.id, :event_type_name => "event06")
      end
      it "ドライバの件数は増えない" do
        expect{
          expect{
            define_driveable_test_class
          }.to_not change(Tengine::Core::Driver, :count)
        }.to_not change(Tengine::Core::HandlerPath, :count)
      end
    end

    context "ロードされたドライバ" do
      before do
        # load(File.expand_path('driveable_spec/driveable_test_class.rb', File.dirname(__FILE__)))
        define_driveable_test_class
      end

      subject{ Tengine::Core::Driver.first }
      its(:name){ should =~ /\ADriveableTestClass/ }
      its(:version){ should_not == nil }
      its(:enabled){ should == true }
      its(:enabled_on_activation){ should == true }
      its(:target_class_name){ should =~ /\ADriveableTestClass/ }

      context "handlers[0]" do
        subject{ Tengine::Core::Driver.first.handlers[0] }
        its(:target_instantiation_key){ should == :instance_method }
        its(:target_method_name){ should == 'foo' }
      end

      context "handlers[1]" do
        subject{ Tengine::Core::Driver.first.handlers[1] }
        its(:target_instantiation_key){ should == :instance_method }
        its(:target_method_name){ should == 'bar' }
      end

      context "handlers[2]" do
        subject{ Tengine::Core::Driver.first.handlers[2] }
        its(:target_instantiation_key){ should == :static }
        its(:target_method_name){ should == 'baz' }
      end

      context "handlers[3]" do
        subject{ Tengine::Core::Driver.first.handlers[3] }
        its(:target_instantiation_key){ should == :static }
        its(:target_method_name){ should == 'hoge' }
      end

      context "インスタンスメソッドによるイベントハンドリング" do
        (0..1).each do |idx|
          context "handlers[#{idx}]" do
            subject{ Tengine::Core::Driver.first.handlers[idx] }
            before do
              @event = mock(:event)
            end
            it "インスタンスが生成される" do
              instance = @klass.new
              @klass.should_receive(:new).with(no_args).and_return(instance)
              STDOUT.should_receive(:puts)
              subject.process_event(@event)
            end
          end
        end

        context "class << self...endで定義したクラスメソッドによるハンドリング" do
          subject{ Tengine::Core::Driver.first.handlers[2] }
          before do
            @event = mock(:event)
          end
          it "インスタンスが生成される" do
            STDOUT.should_receive(:puts)
            subject.process_event(@event)
          end
        end

        context "def self.hogeで定義したクラスメソッドによるハンドリング" do
          subject{ Tengine::Core::Driver.first.handlers[3] }
          before do
            @event = mock(:event)
          end
          it "インスタンスが生成される" do
            STDOUT.should_receive(:puts)
            subject.process_event(@event)
          end
        end

      end
    end

  end


end
