# -*- coding: utf-8 -*-
require 'tengine/core'

require_relative 'safe_updatable'

# Tengine::Core::Mutexは(若干残念な実装の)分散ロック機構です。これを用
# いることで、とあるMutexをロックしているプロセスを同時にたかだか一つに
# 制限することが可能になります。
#
#     mutex = Tengine::Core::Mutex.new "foo"
#     mutex.synchronize do
#        ...
#     end
#
# #### 問題点 ####
#
# このクラスは正しく使わないと正しく使えません。
#
# * スケールしません。当然の話ですが一カ所につき一つのプロセスしか動か
#   ないので、何個プロセスを並列に動かしても無駄です。
#
# * トランザクションではありません。あくまでプロセスが同時に動くのを止
#   めているだけです。データの整合性に関していっさい感知できません。
#
# * スピンロックです。MongoDBの制限による。したがって非効率です。
#
# * ロックしているプロセスが何かの弾みで死ぬかもしれないわけです。そう
#   すると誰もアンロックできなくて詰みます。これを避けるために、一定の
#   時間がたつとロックは勝手に外れるようになっています(一番残念な部分)。
#   長時間ロックするようなプロセスは勝手にロックが外れないようにときど
#   きロックを更新する必要があります。これにはheartbeatを使います。
#
#     mutex.synchronize do
#        ...
#        mutex.heartbeat
#        ...
#        mutex.heartbeat
#        ...
#        mutex.heartbeat
#        ...
#     end

################################################################################

# Poor man's distributed lock.
Tengine::Core::Mutex = Struct.new :mutex, :_id, :recursive

# @api private
class Tengine::Core::Mutex::Mutex

  include Mongoid::Document
  include Tengine::Core::SafeUpdatable

  field :ttl, :type => Float
  field :waiters, :type => Array

  def self.find_or_create name, ttl
    collection.driver.update(
      { :_id => name },
      { "$set" => { :ttl => ttl, }, },
      { :upsert => true, :safe => true, :multiple => false, }
    )
    return find(name)
  end

  private

  # 暫定対応[Bug]mongodbフェールオーバ中にtengine_resource＿watchdが落ちてしまう
  def _update q = {}, r
    update_in_safe_mode(
      self.class.collection,
      { :_id => _id, }.update(q),
      r
    )
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

    # @param [String]  name  Mutex name.  One process at once can gain a lock against a name.
    # @param [Numeric] ttl   Time to auto-release a gained lock.
    # @return [Tengine::Core::Mutex] An instance.
    def new name, ttl=2.048
      t = 0.0 + ttl # type check
      raise TypeError, "finite numeric expected (got #{t})" unless t.finite?
      raise ArgumentError, "TTL doesn't make sense." unless t > 0

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

  def synchronize_internal ttl, blk
    # stop stack consumption
    EM.add_timer ttl do
      begin
        synchronize(&blk)
      rescue Exception => e
        msg = sprintf "%p\n%s", e, e.backtrace.join("\n")
        Tengine.logger.error msg
        # no raise
      end
    end
  end

  public

  # delays until you get a lock.
  def synchronize(&block)
    raise ArgumentError, "no block given" unless block_given?

    if lock
      # OK, locked
      EM.schedule do
        begin
          heartbeat
          yield
        ensure
          unlock
        end
      end
    else
      # NG, try again later
      synchronize_internal mutex.ttl, block
    end
  end

  # If you need to lock it longer than ttl, call this and you can refresh the ttl.
  def heartbeat
    mutex.heartbeat self
  end
end
