# -*- coding: utf-8 -*-
require 'spec_helper'
require 'tengine/core'

describe Tengine::Core::Mutex do
  before do
    Tengine::Core::Mutex::Mutex.delete_all
  end

  context "#new" do
    subject { Tengine::Core::Mutex.new "test mutex 01" }

    it { should be_kind_of(Tengine::Core::Mutex) }
    its(:mutex) { should be_kind_of(Tengine::Core::Mutex::Mutex) }
    its(:recursive) { should be_zero }
  end

  context "#synchronize" do
    subject { Tengine::Core::Mutex.new "test mutex 01", Math::PI / 10 }

    it "requires block" do
      expect {
        subject.synchronize
      }.to raise_exception(ArgumentError)
    end

    it "synchronizes #0: no other lockers" do
      block_called = false
      EM.run_block do
        subject.synchronize do
          block_called = true
        end
      end
      block_called.should be_true
    end

    it "synchronizes #1: with another locker, which is expired" do
      # "stub" waiters
      m = subject.mutex
      m.waiters << { :_id => 1, :timeout => Time.at(0) }
      m.save

      block_called = false
      t0 = Time.now
      EM.run_block do
        subject.synchronize do
          block_called = true
        end
      end
      t1 = Time.now
      block_called.should be_true
      m.reload.waiters.should be_empty
      (t1 - t0).should be_within(0.5).of(0) #immediate
    end

    it "synchronizes #2: with another locker, which is expiring" do
      # "stub" waiters
      m = subject.mutex
      m.waiters << { :_id => 1, :timeout => Time.now + m.ttl / 2 }
      m.save

      block_called = false
      t0 = Time.now
      EM.run do
        subject.synchronize do
          block_called = true
          EM.stop
        end
      end
      t1 = Time.now
      block_called.should be_true
      m.reload.waiters.should be_empty
      (t1 - t0).should be_within(0.5).of(0.3 + m.ttl)
    end

    it "synchronizes #3: with another locker, which is not expiring" do
      # "stub" waiters
      m = subject.mutex
      s = mock("mutex")
      s.stub("_id").and_return(1)
      m.waiters << { :_id => s._id, :timeout => Time.now + 10 }
      m.save

      block_called = false
      t0 = Time.now
      EM.run do
        EM.add_timer 5 do
          m.unlock s
        end
        subject.synchronize do
          block_called = true
          EM.stop
        end
      end
      t1 = Time.now
      block_called.should be_true
      m.reload.waiters.should be_empty
      (t1 - t0).should be_within(0.5).of(5 + m.ttl)
    end
  end
end
