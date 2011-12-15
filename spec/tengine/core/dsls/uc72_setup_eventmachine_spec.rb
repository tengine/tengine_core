# -*- coding: utf-8 -*-
require 'spec_helper'

describe "uc72_setup_eventmachine_spec" do
  before do
    Tengine::Core::Driver.delete_all
    Tengine::Core::Session.delete_all
    @dsl_path = File.expand_path('../../../../examples/uc72_setup_eventmachine.rb', File.dirname(__FILE__))
    config = Tengine::Core::Config::Core.new({
        :tengined => {
          :load_path => @dsl_path,
        },
      })
    @kernel = Tengine::Core::Kernel.new(config)
    @bootstrap = Tengine::Core::Bootstrap.new(config)
    @bootstrap.kernel = @kernel
  end

  it "EM.run実行時にsetup_eventmachineに渡されたブロックが実行されます" do
    @kernel.em_setup_blocks.length.should == 0
    expect{
      @bootstrap.load_dsl
    }.to change(@kernel.em_setup_blocks, :length).by(1)
    @kernel.em_setup_blocks.length.should == 1
    expect{
      @kernel.bind
    }.to_not change(@kernel.em_setup_blocks, :length)
    @kernel.em_setup_blocks.length.should == 1
    EM.should_receive(:run).and_yield
    EM.stub(:defer) # #enable_heartbeat
    mq = mock(:mq, :queue => nil)
    @kernel.stub(:mq).at_least(1).times.and_return(mq)
    @kernel.should_receive(:setup_mq_connection)
    @kernel.should_receive(:subscribe_queue).and_yield
    @kernel.context.should_receive(:puts).with("setup_eventmachine")
    EM.should_receive(:add_periodic_timer).with(3)
    @kernel.activate
  end
end
