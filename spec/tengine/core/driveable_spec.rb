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
      end
    end

    it "クラスを定義するファイルをloadするとドライバが登録されます" do
      expect{
        expect{
          # load(File.expand_path('driveable_spec/driveable_test_class.rb', File.dirname(__FILE__)))
          define_driveable_test_class
        }.to change(Tengine::Core::Driver, :count).by(1)
      }.to change(Tengine::Core::HandlerPath, :count).by(1)
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

      context "handler" do
        subject{ Tengine::Core::Driver.first.handlers.first }
        its(:target_instantiation_key){ should == :instance_method }
        its(:target_method_name){ should == 'foo' }
      end

      context "イベントハンドリングの際" do
        subject{ Tengine::Core::Driver.first.handlers.first }
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

  end


end
