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
      expect{
        Tengine::Core::Event.create!(valid_attributes1)
      }.to raise_error(Mongo::OperationFailure, '11000: E11000 duplicate key error index: tengine_core_test.tengine_core_events.$key_1  dup key: { : "some_unique_key1" }')
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
end
