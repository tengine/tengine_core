# -*- coding: utf-8 -*-
require 'tengine/core/driver'

class Tengine::Core::Driver::Finder

  ATTRIBUTE_NAMES = [
    :name,
    :version,
    :enabled,
    :enabled_on_activation
  ].freeze

  ATTRIBUTE_NAMES.each{|name| attr_accessor(name)}

  def initialize(attrs = {})
    attrs ||= {}
    attrs.each do |attr, v| 
      send("#{attr}=", v) unless v.blank?
    end
  end

  def attributes
    ATTRIBUTE_NAMES.inject({}){|d, name| d[name] = send(name); d}
  end

  def paginate(page)
    scope(Tengine::Core::Driver).page(page)
  end

  def scope(criteria)
    result = criteria
    result = result.where(name: name) if name
    result = result.where(version: version) if version
    result = result.where(enabled: enabled) if enabled
    result = result.where(enabled_on_activation: enabled_on_activation) if enabled_on_activation
    # ソート
    result = result.asc(:_id, :name)
    result
  end

end

