# -*- coding: utf-8 -*-
require 'spec_helper'

describe Tengine::Core::Event do

  valid_attributes1 = {
    :event_type_name => "valid.event-type_name1",
    :key => "some_unique_key1",
  }.freeze

  context "event_type_nameとkeyは必須" do
    it "正常系" do
      Tengine::Core::Event.delete_all
      driver1 = Tengine::Core::Event.new(valid_attributes1)
      driver1.valid?.should == true
    end

    [:event_type_name, :key].each do |key|
      it "#{key}なし" do
        attrs = valid_attributes1.dup
        attrs.delete(key)
        driver1 = Tengine::Core::Event.new(attrs)
        driver1.valid?.should == false
      end
    end
  end

  context "keyはバージョン毎にユニーク" do
    before do
      Tengine::Core::Event.delete_all
      Tengine::Core::Event.create!(valid_attributes1)
    end

    it "同じ名前で登録されているものが存在する場合エラー、しかしunique indexによるエラーが発生します" do
      begin
        Tengine::Core::Event.create!(valid_attributes1)
        fail
      rescue Mongo::OperationFailure => e
        e.message.should =~ /E11000/
        e.message.should =~ /duplicate key error/
        e.message.should =~ /tengine_core_test\.tengine_core_events/
        e.message.should =~ /some_unique_key1/
      end
    end
  end

  context "must be unique with key and sender_name" do
    it "raise an exception when violate unique consistent" do
      Mongoid.persist_in_safe_mode.should == true

      unique_key_name = "key1"
      Tengine::Core::Event.delete_all
      Tengine::Core::Event.create!(:event_type_name => "foo", :key => unique_key_name, :sender_name => "server1")
      expect {
        Tengine::Core::Event.create!(:event_type_name => "foo", :key => unique_key_name, :sender_name => "server2")
      }.to raise_error # (Mongo::OperationFailure, /duplicate key error/)
    end
  end


  describe :level do

    it "i18n_scopeが設定される" do
      Tengine::Core::Event.level_enum.i18n_scope.should == ['selectable_attrs', 'tengine/core/event', 'level']
    end

    context :i18n_scope do
      before(:all) do
        @default_locale_backup = I18n.default_locale
        @locale_backup = I18n.locale
      end

      after(:all) do
        I18n.locale = @locale_backup
        I18n.default_locale = @default_locale_backup
      end

      before do
        I18n.backend = I18n::Backend::Simple.new
        I18n.backend.store_translations 'en', 'selectable_attrs' => {'tengine/core/event' => {'level' => {
            'debug' => 'DEBUG',
            'info'  => 'INFO',
            'warn'  => 'WARN',
            'error' => 'ERROR',
            'fatal' => 'FATAL',
            } } }
        I18n.backend.store_translations 'ja', 'selectable_attrs' => {'tengine/core/event' => {'level' => {
            'debug' => 'デバッグ',
            'info'  => '情報',
            'warn'  => '警告',
            'error' => 'エラー',
            'fatal' => '致命的なエラー',
            } } }
      end

      context "#level_name" do
        {
          :debug => {:en => "DEBUG", :ja => "デバッグ"},
          :info  => {:en => "INFO" , :ja => "情報"},
          :warn  => {:en => "WARN" , :ja => "警告"},
          :error => {:en => "ERROR", :ja => "エラー"},
          :fatal => {:en => "FATAL", :ja => "致命的なエラー"},
        }.each do |level_key, hash|
          context level_key.inspect do
            subject{ Tengine::Core::Event.new(:level_key => level_key)}
            hash.each do |locale, level_name|
              it do
                I18n.locale = locale.to_s
                subject.level_name.should == level_name
              end
            end
          end

        end
      end

    end
  end

end
