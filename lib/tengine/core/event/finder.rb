# -*- coding: utf-8 -*-
class Tengine::Core::Event::Finder

  include ::SelectableAttr::Base

  ATTRIBUTE_NAMES = [
    :event_type_name,
    :key,
    :source_name,
    :occurred_at_start,
    :occurred_at_end,
    :level_ids,
    :confirmed,
    :sender_name,
    :properties,
    :reflesh_interval, # 更新間隔
  ].freeze

  ATTRIBUTE_NAMES.each{|name| attr_accessor(name)}

  # 通知レベル
  multi_selectable_attr :level, :enum => Tengine::Core::Event.level_enum

  def initialize(attrs = {})
    attrs = {
      level_ids: default_level_ids
    }.update(attrs || {})
    attrs.each do |attr, v|
      send("#{attr}=", v) unless v.blank?
    end
  end

  def attributes
    ATTRIBUTE_NAMES.inject({}){|d, name| d[name] = send(name); d}
  end

  # デフォルトでは通知レベルがすべて選択された状態にする
  def default_level_ids
    result = []
    Tengine::Core::Event.level_entries.each do |entry|
      result << entry.id
    end
    return result
  end

  def paginate(page)
    scope(Tengine::Core::Event).page(page)
  end

  def scope(criteria)
    result = criteria
    result = result.where(event_type_name: event_type_name) if event_type_name
    result = result.where(key: key)  if key
    result = result.where(source_name: source_name) if source_name
    result = result.where(:occurred_at.gte => occurred_at_start) if occurred_at_start
    result = result.where(:occurred_at.lte =>  occurred_at_end) if occurred_at_end
    result = result.any_in(level: level_ids) if level_ids
    result = result.where(confirmed: confirmed) if confirmed
    result = result.where(sender_name: sender_name) if sender_name
    result = result.where(properties: properties) if properties
    # ソート
    result = result.desc(:_id)
    result
  end

end

