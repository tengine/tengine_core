# -*- coding: utf-8 -*-
require 'spec_helper'
require 'amqp'

describe "receive_event" do
  before do
    Tengine::Core::Driver.delete_all
    Tengine::Core::HandlerPath.delete_all
    Tengine::Core::Session.delete_all
  end

  it "イベントを登録できる" do
    @config = Tengine::Core::Config::Core.new({
        :tengined => {
          :load_path => File.expand_path('./use_dsl_version_method.rb', File.dirname(__FILE__)),
        },
      })
    expect{
      @config.dsl_version.should_not be_blank
      @bootstrap = Tengine::Core::Bootstrap.new(@config)
      @bootstrap.load_dsl
      @kernel = Tengine::Core::Kernel.new(@config)
      @kernel.bind
    }.to change(Tengine::Core::Driver, :count).by(1)
  end


end
