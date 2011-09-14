# -*- coding: utf-8 -*-
require 'spec_helper'

describe "uc61_event_outside_of_handler" do
  before do
    Tengine::Core::Driver.delete_all
    Tengine::Core::Session.delete_all
    @config = Tengine::Core::Config.new({
        :tengined => {
          :load_path => File.expand_path('../../../../../failure_examples/uc61_event_outside_of_handler.rb', File.dirname(__FILE__)),
        },
      })
  end

  it "ロードは失敗してdriver53は登録されず起動できない" do
    @bootstrap = Tengine::Core::Bootstrap.new(@config)
    expect{
      expect{
        @bootstrap.load_dsl
      }.to raise_error(Tengine::Core::DslError, "event is not available outside of event handler block.")
    }.to_not change(Tengine::Core::Driver, :count)
  end

  it "仮にロードされていてもbindに失敗して起動できない" do
    @kernel = Tengine::Core::Kernel.new(@config)
    driver = Tengine::Core::Driver.new(:name => :driver61, :version => @config.dsl_version)
    driver.handlers.new(:event_type_names => ["event61"])
    driver.save!
    expect{
      @kernel.bind
    }.to raise_error(Tengine::Core::DslError, "event is not available outside of event handler block.")
  end
end
