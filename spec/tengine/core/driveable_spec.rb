# -*- coding: utf-8 -*-
require 'spec_helper'

describe Tengine::Core::Driveable do

  describe :handling_by_instance_method do
    before do
      Tengine::Core::Driver.delete_all
      Tengine::Core::HandlerPath.delete_all
    end

    def define_driveable_test_class
      @@index ||= 0
      @@index += 1
      @klass = Class.new
      Object.const_set(:"DriveableTestClass#{@@index}", @klass)
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

    it "クラスを定義するファイルをloadするとドライバが登録されます" do
      expect{
        expect{
          # load(File.expand_path('driveable_spec/driveable_test_class.rb', File.dirname(__FILE__)))
          define_driveable_test_class
        }.to change(Tengine::Core::Driver, :count).by(1)
      }.to change(Tengine::Core::HandlerPath, :count).by(6)
    end

    context "ロードされたドライバ" do
      before do
        # load(File.expand_path('driveable_spec/driveable_test_class.rb', File.dirname(__FILE__)))
        define_driveable_test_class
      end

      subject{ Tengine::Core::Driver.first }
      its(:name){ should =~ /\ADriveableTestClass/ }
      its(:version){ should_not == nil }
      its(:enabled){ should == nil }
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
