# -*- coding: utf-8 -*-
require 'tengine/core'

module Tengine::Core::KernelRuntime # Kernelにincludeされます

  def safety_processing_headers(headers, event, ack_policy)
    @ack_called = false
    @processing_headers, @event, @ack_policy = headers, event, ack_policy
    begin
      yield if block_given?
    ensure
      @processing_headers, @event, @ack_policy = nil, nil, nil
    end
  end

  def ack_policies
    @ack_policies ||= { }
  end

  def add_ack_policy(event_type_name, policy)
    ack_policies[event_type_name.to_s] = policy.to_sym
  end

  def ack_policy_for(event)
    Tengine.logger.debug("ack_policies: #{ack_policies.inspect}")
    ack_policy = ack_policies[event.event_type_name.to_s] || :at_first
  end

  def ack
    unless @ack_called
      @ack_called = true
      @processing_headers.ack
    end
  end

  def ack?
    @ack_called
  end


  def submit
    if @submitted_handlers
      @submitted_handlers << @handler
    end
  end

  def all_submitted?
    return false if @submitted_handlers.nil? || @handlers.nil?
    (@handlers - @submitted_handlers).empty?
  end


  def processing_event?; @processing_event; end

  private

  def safety_processing_event(headers)
    @processing_event = true
    begin
      yield if block_given?
    ensure
      @processing_event = false
    end
  end

  def safty_handlers(handlers)
    @handlers = handlers
    @submitted_handlers = (@ack_policy == :after_all_handler_submit ? [] : nil)
    begin
      yield if block_given?
    ensure
      @handlers = nil
    end
  end

  def safety_handler(handler)
    @handler = handler
    @submitted_handler = nil
    begin
      yield if block_given?
    ensure
      @handler = nil
    end
  end

end
