# -*- coding: utf-8 -*-
require 'spec_helper'

describe Tengine::Core::Driver do
  context "保存時にHandlerPathを自動的に登録します" do
    before do
      Tengine::Core::Driver.delete_all
      Tengine::Core::HandlerPath.delete_all
      @d11 = Tengine::Core::Driver.new(name:"driver1", version:"1", enabled:true)
      @d11h1 = @d11.handlers.new(:event_type_names => ["foo"])
      @d11h2 = @d11.handlers.new(:event_type_names => ["boo"])
      @d11h3 = @d11.handlers.new(:event_type_names => ["blah"])
      @d11.save!
    end
    it do
      Tengine::Core::HandlerPath.count.should == 3
      Tengine::Core::HandlerPath.event_type_name("foo").map(&:handler_id).should == [@d11h1.id]
      Tengine::Core::HandlerPath.event_type_name("boo").map(&:handler_id).should == [@d11h2.id]
      Tengine::Core::HandlerPath.event_type_name("blah").map(&:handler_id).should == [@d11h3.id]
    end
  end

  context "must have only one session" do
    subject do
      Tengine::Core::Driver.delete_all
      Tengine::Core::Driver.create!(name:"driver1", version:"1", enabled:true)
    end
    its(:session){ should be_a(Tengine::Core::Session)}
  end
end
