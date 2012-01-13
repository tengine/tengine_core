# -*- coding: utf-8 -*-
require 'tengine/core'

# Poor man's distributed lock.
Tengine::Core::Mutex = Struct.new :mutex, :_id, :recursive

# @api private
class Tengine::Core::Mutex::Mutex

  include Mongoid::Document

  field :ttl, :type => Float
  field :waiters, :type => Array
  
  def self.find_or_create name, ttl
    collection.driver.update(
      { :_id => name, :ttl => ttl, },
      { "$set" => { :ttl => ttl, :waiters => [], }, },
      { :upsert => true, :safe => true, :multiple => false, }
    )
    return find(name)
  end

  private

  def _update q = {}, r
    self.class.collection.driver.update({ :_id => _id, }.update(q), r, {:safe=>true})
    reload
  end

  public

  # delete stale locks
  def invalidate
    # can this be done via standard mongoid queries?
    _update("$pull" => { :waiters => { :timeout => { "$lt" => Time.now, }, }, } )
  end

  # attempt to gain lock
  def lock id
    _update("$push" => { :waiters => { :_id => id._id, :timeout => Time.now + ttl, }, })
  end

  # attempt to release lock
  def unlock id
    _update("$pull" => { :waiters => { :_id => id._id, }, })
  end

  # attempt to refresh lock
  def heartbeat id
    _update(
      { :_id => _id, "waiters._id" => id._id, },
      { "$set" => { "waiters.$.timeout" => Time.now + ttl, }, }
    )
  end
end

class Tengine::Core::Mutex

  class << self

    alias oldnew new
    private :oldnew

    def new name, ttl=2.048
      t = 0.0 + ttl # type check
      raise TypeError, "finite numeric expected (got #{t})" unless t.finite?

      return oldnew(Tengine::Core::Mutex::Mutex.find_or_create(name, t), BSON::ObjectId.new, 0)
    end
  end

  private

  def lock_attempt
    m = mutex
    m.invalidate
    m.lock self
    return m.waiters.first["_id"] == _id
  end

  def lock
    if lock_attempt
      self.recursive += 1
    end
  end

  def unlock
    self.recursive -= 1
    if self.recursive <= 0
      mutex.unlock self
    end
  end

  public

  # delays until you get a lock.
  def synchronize
    raise ArgumentError, "no block given" unless block_given?

    if lock
      # OK, locked
      begin
        EM.schedule do
          heartbeat
          yield
        end
      ensure
        unlock
      end
    else
      # NG, try again later
      EM.add_timer mutex.ttl do
        synchronize do
          yield
        end
      end
    end
  end

  def heartbeat
    mutex.heartbeat self
  end
end
