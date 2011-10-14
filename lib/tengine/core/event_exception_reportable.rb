require 'tengine/core'

module Tengine::Core::EventExceptionReportable
  extend ActiveSupport::Concern

  FIRE_ON_ALL_EXCEPTION = lambda do |kernel, dsl_context, event, exception, block|
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
    unless exception.class.name =~ /^Test::|^MiniTest::|^RSpec::|^Spec::/
      FIRE_ON_ALL_EXCEPTION.call(kernel, dsl_context, event, exception, block)
    end
  end

  EVENT_EXCEPTION_REPORTERS = {
    :all => FIRE_ON_ALL_EXCEPTION,
    :except_test => FIRE_EXCEPT_TESTING_ERROR,
  }.freeze

  module ClassMethods
    def event_exception_reporter
      unless defined?(@event_exception_reporter)
        @event_exception_reporter = FIRE_ON_ALL_EXCEPTION
      end
      @event_exception_reporter
    end

    def event_exception_reporter=(reporter)
      if reporter.is_a?(Symbol)
        reporter = EVENT_EXCEPTION_REPORTERS[reporter]
      end
      @event_exception_reporter = reporter
    end
  end

  module InstanceMethods
    def report_on_exception(dsl_context, event, block)
      begin
        yield
      rescue Exception => e
        Tengine.logger.debug("[#{e.class.name}] #{e.message}\n  " << e.backtrace.join("\n  "))
        if reporter = Tengine::Core::Kernel.event_exception_reporter
          reporter.call(self, dsl_context, event, e, block)
        end
      end
    end

  end

end
