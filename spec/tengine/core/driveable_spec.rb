# -*- coding: utf-8 -*-
require 'spec_helper'

describe Tengine::Core::Driveable do

  describe :handling_by_instance_method do
    before do
      Tengine::Core::Driver.delete_all
      Tengine::Core::HandlerPath.delete_all
    end

    def define_uc01_execute_processing_for_event
      @@index ||= 0
      @@index += 1
      klass = Class.new
      Object.const_set(:"Uc01ExecuteProcessingForEvent#{@@index}", klass)
      klass.module_eval do
        include Tengine::Core::Driveable
        on:event01
        def foo
          puts "#{self.class.name}#foo"
        end
      end
    end

    it "クラスを定義するファイルをloadするとドライバが登録されます" do
      expect{
        expect{
          # load(File.expand_path('driveable_spec/uc01_execute_processing_for_event.rb', File.dirname(__FILE__)))
          define_uc01_execute_processing_for_event
        }.to change(Tengine::Core::Driver, :count).by(1)
      }.to change(Tengine::Core::HandlerPath, :count).by(1)
    end

    context "ロードされたドライバ" do
      before do
        # load(File.expand_path('driveable_spec/uc01_execute_processing_for_event.rb', File.dirname(__FILE__)))
        define_uc01_execute_processing_for_event
      end

      subject{ Tengine::Core::Driver.first }
      its(:name){ should =~ /\AUc01ExecuteProcessingForEvent/ }
      its(:version){ should_not == nil }
      its(:enabled){ should == nil }
      its(:enabled_on_activation){ should == true }
      its(:target_class_name){ should =~ /\AUc01ExecuteProcessingForEvent/ }

      context "handler" do
        subject{ Tengine::Core::Driver.first.handlers.first }
        its(:target_instantiation_key){ should == :instance_method }
        its(:target_method_name){ should == 'foo' }
      end

    end

  end


end
