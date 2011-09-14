# -*- coding: utf-8 -*-
require 'tengine/core'

# ハンドラ内では event メソッドを使って受け取ったイベントを取得する事が可能。
# イベントの属性については、Tengine::Core::Event を参照

driver :driver60 do
  on:event60 do
Tengine.logger.debug("*" * 100)
Tengine.logger.debug( "event: #{event.inspect}" )
    hash = {}
    [:event_type_name, :key, :source_name, :occurred_at,
      :level, :confirmed, :sender_name, :properties,].each do |attr_name|
      hash[attr_name.to_s] = event.send(attr_name)
    end
    puts "handler60: " << hash.to_a.sort.inspect
  end
end
