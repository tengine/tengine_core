# -*- coding: utf-8 -*-
puts "*" * 100
puts "#{__FILE__} is loaded"

require 'tengine/core'

class Driver01
  include Tengine::Core::Driveable

  on:event01
  def event01
    puts "#" * 100
    puts "handler01"
    puts "Driver01.object_id: #{Driver01.object_id.inspect}"
    puts "ActiveSupport::Dependencies.loaded: #{ActiveSupport::Dependencies.loaded.inspect}"
  end

end
