# -*- coding: utf-8 -*-
require 'tengine/rspec'

# Kernelのcontextをラップするクラスです
class Tengine::RSpec::ContextWrapper
  attr_accessor :__driver__

  def initialize(kernel)
    @kernel = kernel
    @context = @kernel.context
  end

  def receive(event_type_name, options = {})
    mock_headers = Object.new
    mock_headers.should_receive(:ack)
    raw_event = Tengine::Event.new({:event_type_name => event_type_name}.update(options || {}))
    @kernel.process_message(mock_headers, raw_event.to_json)
  end

  def should_receive(*args)
    @context.should_receive(*args)
  end

  def should_not_receive(*args)
    @context.should_not_receive(*args)
  end

  def should_fire(*args)
    # receiver = @context
    receiver = __driver_object__
    receiver.should_receive(:fire).with(*args)
  end
  def should_not_fire(*args)
    # receiver = @context
    receiver = __driver_object__
    if args.empty?
      receiver.should_not_receive(:fire)
    else
      receiver.should_not_receive(:fire).with(*args)
    end
  end

  def __driver_class__
    @__driver_class__ ||= __driver__.target_class_name.constantize
  end

  def __driver_object__
    unless @__driver_object__
      @__driver_object__ = __driver_class__.new
      __driver_class__.stub(:new).and_return(@__driver_object__)
    end
    @__driver_object__
  end

end
