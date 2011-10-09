# -*- coding: utf-8 -*-
require 'tengine/rspec'

# Kernelのcontextをラップするクラスです
class Tengine::RSpec::ContextWrapper
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
    @context.should_receive(:fire).with(*args)
  end
  def should_not_fire(*args)
    if args.empty?
      @context.should_not_receive(:fire)
    else
      @context.should_not_receive(:fire).with(*args)
    end
  end
end
