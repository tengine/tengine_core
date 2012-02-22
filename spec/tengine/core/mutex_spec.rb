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

    context "negative ttl" do
      it { expect { Tengine::Core::Mutex.new "test negative ttl", -1 }.to raise_exception(ArgumentError) }
    end

    context "infinite ttl" do
      it { expect { Tengine::Core::Mutex.new "test negative ttl", (1.0 / 0.0) }.to raise_exception(TypeError) }
    end
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
      m.waiters ||= []
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
      m.waiters ||= []
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
      (t1 - t0).should be_within(1.0).of(0.3 + m.ttl)
    end

    it "synchronizes #3: with another locker, which is not expiring" do
      # "stub" waiters
      m = subject.mutex
      s = mock("mutex")
      s.stub("_id").and_return(1)
      m.waiters ||= []
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
      (t1 - t0).should be_within(1.0).of(5 + m.ttl)
    end

    it "synchronizes #4: multi-threaded situation" do
      x = y = z = nil

      EM.run do
        EM.defer do
          m = Tengine::Core::Mutex.new "test mutex 02"
          m.synchronize do
            x = Time.now.to_f
          end
          y = Time.now.to_f
        end

        EM.defer do
          sleep 0.5
          m = Tengine::Core::Mutex.new "test mutex 02"
          m.synchronize do
            z = Time.now.to_f
          end
        end

        EM.add_timer(2.5) do
          EM.stop
        end
      end

      x.should_not be_nil
      y.should_not be_nil
      z.should_not be_nil
      x.should < z
      y.should <= z
    end

    it "synchronizes #5: no stack overflow" do
      STDERR.puts "This test takes two minutes to run.  Relax and take a cup of coffee."
      m = Tengine::Core::Mutex.new "test mutex 03", 0.00000000001
      n = m.mutex
      n.waiters ||= []
      n.waiters << { :_id => 1, :timeout => Time.now + 120 }
      n.save

      expect do
        EM.run do
          m.synchronize do
            EM.stop
          end
        end
      end.to_not raise_error(SystemStackError)
    end
  end

  context "#heartbeat" do
    subject { Tengine::Core::Mutex.new "test mutex 01", Math::PI / 10 }

    it "prevents automatic unlocking" do
      m = subject.mutex
      t1 = nil
      t0 = Time.now.to_f
      EM.run do
        EM.defer do
          subject.synchronize do
            20.times do
              subject.heartbeat
              sleep(m.ttl / 2)
            end
          end
        end
        EM.defer do
          sleep m.ttl
          loop do
            # hacky...
            if h = m.reload.waiters.first
              if h["timeout"] < Time.now
                t1 = Time.now.to_f
                EM.stop
                break
              end
            else
              t1 = Time.now.to_f
              EM.stop
              break
            end
          end
        end
      end

      t1.should_not be_nil
      (t1 - t0).should be_within(1.0).of(10 * subject.mutex.ttl)
    end
  end
end
