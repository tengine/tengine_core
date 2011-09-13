# -*- coding: utf-8 -*-
require 'tengine/core'

class Tengine::Core::SessionWrapper

  def initialize(source, options = {})
    @options = options || {}
    @source = source
  end

  def [](key)
    @source.properties[key.to_s]
  end

  def update(properties)
    Tengine.logger.debug("*" * 100)
    Tengine.logger.debug("#{self.inspect}")
    Tengine.logger.debug("#{properties.inspect}")
    new_vals = @source.properties.merge(properties.stringify_keys)
    @source.properties = new_vals
    @source.save! unless @options[:ignore_update]
  end

end
