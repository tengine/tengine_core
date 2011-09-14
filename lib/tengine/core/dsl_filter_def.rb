require 'tengine/core'

class Tengine::Core::DslFilterDef
  attr_reader :filter
  attr_reader :event_type_names
  def initialize(event_type_names, filter)
    @event_type_names = event_type_names
    @filter = filter
  end

end
