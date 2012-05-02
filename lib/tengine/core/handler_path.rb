require 'tengine/core'

class Tengine::Core::HandlerPath
  include Mongoid::Document
  include Mongoid::Timestamps

  field :event_type_name, :type => String
  field :handler_id, :type => Object

  belongs_to :driver, :index => true, :class_name => "Tengine::Core::Driver"

  scope(:event_type_name, lambda{|v| where(:event_type_name => v)})

  index([ [:event_type_name, Mongo::ASCENDING], [:_id, Mongo::ASCENDING], ])

  class << self
    def find_handlers(event_type_name)
      paths = self.event_type_name(event_type_name).to_a
      driver_id_to_handler_id = paths.inject({}) do |d, path|
        d[path.driver_id] ||= []
        d[path.driver_id] << path.handler_id
        d
      end
      drivers = Tengine::Core::Driver.any_in(:_id => paths.map(&:driver_id)).and(:enabled => true, :version => default_driver_version)
      drivers.map do |driver|
        driver.handlers.any_in(:_id => driver_id_to_handler_id[driver.id])
      end.flatten
    end

    attr_accessor :default_driver_version

  end
end
