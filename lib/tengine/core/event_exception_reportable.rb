require 'tengine/core'

module Tengine::Core::EventExceptionReportable
  extend ActiveSupport::Concern

  FIRE_ALL = lambda do |kernel, dsl_context, event, exception, block|
    dsl_context.fire("#{event.event_type_name}.error.tengined",
      :properties => {
        :original_event => event.to_json,
        :error_class_name => exception.class.name,
        :error_message => exception.message,
        :error_backtrace => exception.backtrace,
        :block_source_location => '%s:%d' % block.source_location,
      })
  end

  FIRE_EXCEPT_TESTING_ERROR = lambda do |kernel, dsl_context, event, exception, block|
    if exception.class.name =~ /^Test::|^MiniTest::|^RSpec::|^Spec::/
      raise exception
    else
      FIRE_ALL.call(kernel, dsl_context, event, exception, block)
    end
  end

  RAISE_ALL = lambda do |kernel, dsl_context, event, exception, block|
    raise exception
  end

  EVENT_EXCEPTION_REPORTERS = {
    :fire_all => FIRE_ALL,
    :raise_all => RAISE_ALL,
    :except_test => FIRE_EXCEPT_TESTING_ERROR,
  }.freeze

  class << self
    def to_reporter(reporter)
      if reporter.is_a?(Symbol)
        result = EVENT_EXCEPTION_REPORTERS[reporter]
        raise NameError, "Unknown reporter: #{reporter.inspect}" unless result
        result
      elsif reporter.respond_to?(:call)
        reporter
      else
        raise ArgumentError, "Invalid reporter: #{reporter.inspect}"
      end
    end
  end

  module ClassMethods
    def event_exception_reporter
      unless defined?(@event_exception_reporter)
        @event_exception_reporter = FIRE_ALL
      end
      @event_exception_reporter
    end

    def event_exception_reporter=(reporter)
      @event_exception_reporter =
        Tengine::Core::EventExceptionReportable.to_reporter(reporter)
    end

    def temp_exception_reporter(reporter)
      backup = self.event_exception_reporter
      begin
        self.event_exception_reporter = reporter
        yield if block_given?
      ensure
        self.event_exception_reporter = backup
      end
    end

  end

  module InstanceMethods
    def report_on_exception(dsl_context, event, block)
      begin
        yield
      rescue Exception => e
        Tengine.logger.error("[#{e.class.name}] #{e.message}\n  " << e.backtrace.join("\n  "))
        if reporter = Tengine::Core::Kernel.event_exception_reporter
          reporter.call(self, dsl_context, event, e, block)
        end
      end
    end

  end

end
