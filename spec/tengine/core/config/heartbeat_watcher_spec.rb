# -*- coding: utf-8 -*-
require 'spec_helper'

require 'tengine/event'

describe Tengine::Core::Config::HeartbeatWatcher do

  describe :[] do
    it "should convert a Hash to a Tengine::Core::Config::HeartbeatWatcher" do
      converted = Tengine::Core::Config::HeartbeatWatcher[{:process => {:daemon => true}}]
      converted.should be_a(Tengine::Core::Config::HeartbeatWatcher)
      converted[:process][:daemon].should be_true
    end

    it "should return same Tengine::Core::Config::HeartbeatWatcher" do
      converted = Tengine::Core::Config::HeartbeatWatcher.new(:process => {:daemon => true})
      Tengine::Core::Config::HeartbeatWatcher[converted].should == converted
    end
  end

  context "デフォルト" do
    subject do
      Tengine::Core::Config::HeartbeatWatcher.new
    end
    its(:db){ should == {
        'host' => 'localhost',
        'port' => 27017,
        'username' => nil,
        'password' => nil,
        'database' => 'tengine_production',
      }}

    it "db" do
      subject.db.should == {
        'host' => 'localhost',
        'port' => 27017,
        'username' => nil,
        'password' => nil,
        'database' => 'tengine_production',
      }
    end

    it "process_daemon" do
      subject[:process][:daemon].should be_false
    end

    it "heartbeat_hbw" do
      subject[:heartbeat][:hbw][:interval].should == 0
    end

  end

  context "指定した設定ファイルが存在しない場合" do
    it "例外を生成します" do
      config_path = File.expand_path("../config_spec/unexist_config.yml", File.dirname(__FILE__))
      expect{
        Tengine::Core::Config::HeartbeatWatcher.new(:config => config_path)
      }.to raise_error(Tengine::Core::ConfigError, /No such file or directory - #{config_path}/)
    end
  end

end
