# -*- coding: utf-8 -*-
require 'spec_helper'

describe "uc72_setup_eventmachine_spec" do
  before do
    Tengine::Core::Driver.delete_all
    Tengine::Core::Session.delete_all
    @dsl_path = File.expand_path('../../../../examples/uc72_setup_eventmachine.rb', File.dirname(__FILE__))
    config = Tengine::Core::Config.new({
        :tengined => {
          :load_path => @dsl_path,
        },
      })
    @bootstrap = Tengine::Core::Bootstrap.new(config)
    @kernel = Tengine::Core::Kernel.new(config)
  end

  it "EM.run実行時にsetup_eventmachineに渡されたブロックが実行されます" do
    @bootstrap.load_dsl
    expect{
      @kernel.bind
    }.to change(@kernel.em_setup_blocks, :length).by(1)
    EM.should_receive(:run).and_yield
    EM.stub(:defer)
    mq = mock(:mq, :queue => nil)
    mq.stub(:wait_for_connection).and_yield
    @kernel.should_receive(:mq).at_least(1).times.and_return(mq)
    @kernel.should_receive(:setup_mq_connection)
    @kernel.should_receive(:subscribe_queue)
    @kernel.context.should_receive(:puts).with("setup_eventmachine")
    EM.should_receive(:add_periodic_timer).with(3)
    @kernel.activate
  end

end
