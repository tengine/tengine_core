# -*- coding: utf-8 -*-
require 'spec_helper'

describe Tengine::Core::OptimisticLock do

  class Tengine::Core::OptimisticLockTestBox1
    include Mongoid::Document
    include Tengine::Core::OptimisticLock

    set_locking_field :version

    field :version, :type => Integer
    field :value, :type => String
  end

  context "update_with_lock" do
    before do
      @test_box1 = Tengine::Core::OptimisticLockTestBox1.create!(:version => 2, :value => "foo")
    end

    it "競合がなければ素直に更新する" do
      test_box = Tengine::Core::OptimisticLockTestBox1.find(@test_box1.id)
      test_box.update_with_lock do
        test_box.value += "o"
      end
      test_box.reload
      test_box.value.should == "fooo"
      test_box.version.should == 3
    end

    it "競合しても単純に上書きしたりせず、最新を取得し直して更新する" do
      test_box1 = Tengine::Core::OptimisticLockTestBox1.find(@test_box1.id)
      test_box2 = Tengine::Core::OptimisticLockTestBox1.find(@test_box1.id)
      # test_box1を更新
      test_box1_count = 0
      test_box1.update_with_lock do
        test_box1_count += 1
        test_box1.value += "o"
      end
      test_box1_count.should == 1
      test_box1.value.should == "fooo"
      test_box1.version.should == 3
      # test_box2を更新
      test_box2_count = 0
      test_box2.update_with_lock do
        test_box2_count += 1
        test_box2.value += "w"
      end
      test_box2_count.should == 2
      test_box2.value.should == "fooow"
      test_box2.version.should == 4
    end
  end

end
