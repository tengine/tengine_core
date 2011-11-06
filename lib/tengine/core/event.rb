# -*- coding: utf-8 -*-
require 'tengine/core'

require 'selectable_attr'

class Tengine::Core::Event
  autoload :Finder, 'tengine/core/event/finder'

  include Mongoid::Document
  include Mongoid::Timestamps
  include Tengine::Core::Validation
  include Tengine::Core::SelectableAttr

  field :event_type_name, :type => String
  field :key            , :type => String
  field :source_name    , :type => String
  field :occurred_at    , :type => Time
  field :level          , :type => Integer, :default => 2
  field :confirmed      , :type => Boolean
  field :sender_name    , :type => String
  field :properties     , :type => Hash
  map_yaml_accessor :properties

  validates :event_type_name, :presence => true #, :format => EVENT_TYPE_NAME.options

  # 以下の２つはバリデーションを設定したいところですが、外部からの入力は極力保存できる
  # ようにしたいのでバリデーションを外します。
  # validates :source_name, :presence => true #, :format => RESOURCE_IDENTIFIER.options
  # validates :sender_name, :presence => true #, :format => RESOURCE_IDENTIFIER.options

  # 複数の経路から同じ意味のイベントが複数個送られる場合に
  # これらを重複して登録しないようにユニーク制約を設定
  index :key, unique: true
  # :unique => trueのindexを設定しているので、uniquenessのバリデーションは設定しません
  validates :key, :presence => true #, :uniqueness => true

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

  def to_hash
    [:event_type_name,
     :key,
     :source_name,
     :occurred_at,
     :level,
     :confirmed,
     :sender_name,
     :properties
    ].inject({}) {|r, i| r.update i => send(i) }
  end
end
