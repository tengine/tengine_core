# -*- coding: utf-8 -*-
require 'tengine/core'

class Tengine::Core::EventWrapper

  def initialize(source)
    @source = source
  end

  [:event_type_name, :key, :source_name, :occurred_at,
    :level, :confirmed, :sender_name, :properties,].each do |attr_name|
    class_eval(<<-EOS)
      def #{attr_name}; @source.#{attr_name}; end
    EOS
  end

  def [](key)
    properties[key.to_s]
  end

end
