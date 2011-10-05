# -*- coding: utf-8 -*-
require 'spec_helper'

require 'tengine/event'

describe Tengine::Core::EventWrapper do
  context "[]でpropertiesの属性にアクセス可能" do
    before do
      @event = Tengine::Core::Event.create!(
        :key => Tengine::Event.uuid_gen.generate,
        :event_type_name => "foo",
        :sender_name => "server1",
        :properties => {
          :foo => [1,2,3,4],
          :bar => "BAR"
        })
      @event.reload
    end

    subject do
      Tengine::Core::EventWrapper.new(@event)
    end

    it do
      @event.properties['foo'].should == [1,2,3,4]
      @event.properties[:foo].should == nil
      subject.properties['foo'].should == [1,2,3,4]
      subject.properties[:foo].should == nil
      subject['foo'].should == [1,2,3,4]
      subject[:foo].should == [1,2,3,4]
      subject['bar'].should == "BAR"
      subject[:bar].should == "BAR"
    end
  end
end
