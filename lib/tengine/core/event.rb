# -*- coding: utf-8 -*-
require 'tengine/core'

require 'selectable_attr'

class Tengine::Core::Event
  autoload :Finder, 'tengine/core/event/finder'

  include Mongoid::Document
  include Mongoid::Timestamps
  include Tengine::Core::Validation
  include Tengine::Core::SelectableAttr
  include Tengine::Core::CollectionAccessible

  field :lock_version   , :type => Integer, :default => -(2**63)
  field :event_type_name, :type => String
  field :key            , :type => String
  field :source_name    , :type => String
  field :occurred_at    , :type => Time
  field :level          , :type => Integer, :default => 2
  field :confirmed      , :type => Boolean
  field :sender_name    , :type => String
  field :properties     , :type => Hash
  map_yaml_accessor :properties

  validates :event_type_name, :presence => true, :format => EVENT_TYPE_NAME.options

  # 以下の２つはバリデーションを設定したいところですが、外部からの入力は極力保存できる
  # ようにしたいのでバリデーションを外します。
  # validates :source_name, :presence => true #, :format => RESOURCE_IDENTIFIER.options
  # validates :sender_name, :presence => true #, :format => RESOURCE_IDENTIFIER.options

  # 複数の経路から同じ意味のイベントが複数個送られる場合に
  # これらを重複して登録しないようにユニーク制約を設定
  index :key, unique: true
  # :unique => trueのindexを設定しているので、uniquenessのバリデーションは設定しません
  validates :key, :presence => true #, :uniqueness => true

  index([ [:event_type_name, Mongo::ASCENDING], [:confirmed, Mongo::ASCENDING], ])
  index([ [:event_type_name, Mongo::ASCENDING], [:level, Mongo::ASCENDING], [:occurred_at, Mongo::DESCENDING], ])
  index([ [:event_type_name, Mongo::ASCENDING], [:occurred_at, Mongo::ASCENDING], ])
  index([ [:event_type_name, Mongo::ASCENDING], [:source_name, Mongo::ASCENDING], ])
  index([ [:level, Mongo::ASCENDING], [:sender_name, Mongo::ASCENDING], [:occurred_at, Mongo::DESCENDING], ])
  index([ [:level, Mongo::ASCENDING], [:occurred_at, Mongo::DESCENDING], ])
  index([ [:source_name, Mongo::ASCENDING], [:level, Mongo::ASCENDING], [:occurred_at, Mongo::DESCENDING], ])

  # selectable_attrを使ってます
  # see http://github.com/akm/selectable_attr
  #     http://github.com/akm/selectable_attr_rails
  selectable_attr :level do
    entry 1, :debug       , "debug"
    entry 2, :info        , "info"
    entry 3, :warn        , "warn"
    entry 4, :error       , "error"
    entry 5, :fatal       , "fatal"
  end

  attr_accessor :kernel # tengined実行時に処理しているカーネルのインスタンスを保持します

  def to_hash
    ret = attributes.dup # <- dup ?
    ret.delete "_id"
    ret
  end

  # TODO: Tengine::Core::OptimisticLockを拡張して、ここでも使えるよう
  # にする。現状は同じようなコードが複数箇所にあってよくない。

  # @yield                      [event]                Yields the (possibly new) event.
  # @yieldparam  [Tengine::Core::Event] event          The event in question.
  # @yieldreturn              [Boolean]                Return false, and it will just break the execution.  Otherwise, it tries to update the event.
  # @param                       [Hash] condition      Criteria to find a document.
  # @param                    [Numeric] retry_max (60)  Maximum number of retry attempts to save the event.
  # @param                    [Numeric] wtimeout  (10240)  Write timeout, ignored for earlier mongodb.
  # @return      [Tengine::Core::Event]                The event in question if update succeeded, false if retry_max reached, or nil if the block exited with false.
  # @raise    [Mongo::OperationFailure]                Any exceptions that happened inside will be propagated outside.
  def self.find_or_create_then_update_with_block condition, retry_max = 60, wtimeout = 10240
    # * とある条件を満たすイベントがあれば、それを上書きしたい。
    # * なければ、新規作成したい。
    # * でもアトミックにやりたい。
    # * ないとおもって新規作成しようとしたら裏でイベントが生えていたら、上書きモードでやり直したい。
    # * あるとおもって上書きしようとしたら裏でイベントが消えていたら、新規作成モードでやり直したい。
    # * という要求をできるだけ高速に処理したい。

    the_event = nil
    retries = -1
    results = nil

    case collection.driver.db.connection when Mongo::ReplSetConnection then
      safemode = { :w => "majority", :wtimeout => wtimeout, } # mongodb 2.0+, 参加しているレプリカセットの多数派に書き込んだ時点でOK扱い
    else
      safemode = true
    end

    while true do
      return false if retries >= retry_max # retryしすぎ

      retries += 1
      # あればとってくる
      if the_event and not the_event.new_record?
        the_event.reload
      else
        the_event = where(condition).first || new(condition)
      end

      return nil if not yield(the_event) # ユザーによる意図的な中断

      hash = the_event.as_document.dup # <- dup ?
      hash.delete "_id"
      hash['lock_version'] = the_event.lock_version + 1
      hash['created_at'] ||= Time.at(Time.now.to_i)
      hash['updated_at'] = Time.at(Time.now.to_i)

      begin
        results = collection.driver.update(
          { :key => the_event.key, :lock_version => the_event.lock_version },
          { "$set" => hash },
          { :upsert => true, :safe => safemode, :multiple => false }
        )
      rescue Mongo::OperationFailure => e
        # upsert = trueだがindexのunique制約があるので重複したkeyは
        # 作成不可、lock_versionの更新失敗はこちらに来る。これは意
        # 図した動作なのでraiseしない。
        Tengine.logger.debug "retrying due to mongodb error #{e}"
        # lock_versionが存在しない可能性(そのような古いDBを引きずっている等)
        collection.driver.update(
          { :key => the_event.key, :lock_version => { "$exists" => false } },
          { "$set" => { :lock_version => -(2**63) } },
          { :upsert => false, :safe => $safemode, :multiple => false }
        )
      else
        if results["error"]
          raise Mongo::OperationFailure, results["error"]
        elsif results["upserted"]
          # *hack* _idを消してupsertしたので、このとき_idは新しくなっている
          the_event.write_attributes "_id" => results["upserted"]
          the_event.reload
          return the_event
        else
          the_event.reload
          return the_event
        end
      end
    end
  end
end
