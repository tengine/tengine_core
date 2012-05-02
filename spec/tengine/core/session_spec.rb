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

    it "競合しても単純に上書きしたりせず、最新を取得し直して更新する" do
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

    it "リトライ回数をオーバーすると例外が発生する" do
      session1 = Tengine::Core::Session.find(@session1.id)
      session2 = Tengine::Core::Session.find(@session1.id)

      session1.update_with_lock{ session1.properties['key1'] += 1 } # [2] 100 -> [3] 101

      f = Fiber.new do
        session2.update_with_lock(:retry => 3) do
          Fiber.yield
          session1.properties['key1'] += 1
        end
      end
      f.resume # [2] 100 -> [3] 101 を試みて失敗

      session1.reload; session1.update_with_lock{ session1.properties['key1'] += 1 } # [3] 101 -> [4] 102
      f.resume # [3] 101 -> [4] 102 を試みて失敗。リトライ1回

      session1.reload; session1.update_with_lock{ session1.properties['key1'] += 1 } # [4] 102 -> [5] 103
      f.resume # [4] 102 -> [5] 103 を試みて失敗。リトライ2回

      session1.reload; session1.update_with_lock{ session1.properties['key1'] += 1 } # [5] 103 -> [6] 104
      expect{
        f.resume # [5] 103 -> [6] 104 を試みて失敗。リトライ3回失敗したので、例外がraiseされる
      }.to raise_error(Tengine::Core::OptimisticLock::RetryOverError)
    end

  end

end
