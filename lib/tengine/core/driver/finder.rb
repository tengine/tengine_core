# -*- coding: utf-8 -*-
class Tengine::Core::Driver::Finder

  attr_accessor :name
  attr_accessor :version
  attr_accessor :enabled
  attr_accessor :enabled_on_activation

  def initialize(attrs = {}, page = {})
    attrs.each do |attr, v| 
      send("#{attr}=", v) unless v.blank?
    end
    @page = page
  end

  def paginate
    scope(Tengine::Core::Driver).page(@page)
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

