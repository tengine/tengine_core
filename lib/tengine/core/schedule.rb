# -*- coding: utf-8 -*-
require 'tengine/core'

class Tengine::Core::Schedule
  include Mongoid::Document
  include Mongoid::Timestamps

  field :event_type_name, :type => String
  field :scheduled_at   , :type => Time
  field :status         , :type => Integer
  field :source_name    , :type => String
end
