# -*- coding: utf-8 -*-
require 'spec_helper'

describe Tengine::Core::Session do
  context "should save Hash as properties" do
    subject do
      Tengine::Core::Session.create!(:properties => {
          "key1" => 100,
          "key2" => "string value",
          "key3" => Time.utc(2011,9,4,20,58),
          :key4 => [:array, "of", "variables", true, false, nil, 99.9999],
          :key5 => {:nested => "hash"},
          :key6 => :symbol_value,
        })
    end
    it do
      subject.properties["key1"].should == 100
      subject.properties["key2"].should == "string value"
      subject.properties["key3"].should == Time.utc(2011,9,4,20,58)
      subject.properties[:key4].should == [:array, "of", "variables", true, false, nil, 99.9999]
      subject.properties[:key5].should == {:nested => "hash"}
      subject.properties[:key6].should == :symbol_value
    end
    it "should allow to read properties by using []" do
      subject["key1"].should == 100
      subject["key2"].should == "string value"
      subject["key3"].should == Time.utc(2011,9,4,20,58)
      subject[:key4].should == [:array, "of", "variables", true, false, nil, 99.9999]
      subject[:key5].should == {:nested => "hash"}
      subject[:key6].should == :symbol_value
    end
    it "should allow to write properties by using []=" do
      subject["key1"] = 99
      subject["key1"].should == 99
    end
  end

  describe :update_with_lock do
    before do
      @session1 = Tengine::Core::Session.create!(
        :lock_version => 2,
        :properties => {
          "key1" => 100,
          "key2" => "string value",
          "key3" => Time.utc(2011,9,4,20,58),
          :key4 => [:array, "of", "variables", true, false, nil, 99.9999],
          :key5 => {:nested => "hash"},
          :key6 => :symbol_value,
        })
    end

    it "競合がなければ素直に更新する" do
      session = Tengine::Core::Session.find(@session1.id)
      session.update_with_lock do
        session.properties['key1'] += 1
      end
      session.reload
      session.properties['key1'].should == 101
    end

    it "競合がしても上書きしない" do
      session1 = Tengine::Core::Session.find(@session1.id)
      session2 = Tengine::Core::Session.find(@session1.id)
      # session1を更新
      session1.update_with_lock do
        session1.properties['key1'] += 1
      end
      session1.properties['key1'].should == 101
      # session2を更新
      session1.update_with_lock do
        session1.properties['key1'] += 1
      end
      session1.properties['key1'].should == 102
    end

  end

end
