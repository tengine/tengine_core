# -*- coding: utf-8 -*-
require 'tengine/core'

require 'selectable_attr'

class Tengine::Core::Event
  autoload :Finder, 'tengine/core/event/finder'

  include Mongoid::Document
  include ::SelectableAttr::Base
  field :event_type_name, :type => String
  field :key, :type => String
  field :source_name, :type => String
  field :occurred_at, :type => Time
  field :level, :type => Integer
  field :confirmed, :type => Boolean
  field :sender_name, :type => String
  field :properties, :type => Hash
  map_yaml_accessor :properties

  # 複数の経路から同じ意味のイベントが複数個送られる場合に、これらを重複して登録しないようにユニーク制約を設定
  index :key, unique: true

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

end
