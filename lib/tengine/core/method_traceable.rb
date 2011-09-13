module Tengine::Core::MethodTraceable

  class << self
    attr_accessor :disabled
  end

  def method_trace(*symbols)
    symbols.each do |symbol|
      original_method = :"_unmethod_traceable_#{symbol}"
      class_eval(<<-EOS, __FILE__, __LINE__ +1)
        if method_defined?(:#{original_method})                                  # if method_defined?(:_unmemoized_mime_type)
          raise "Already method_tracing #{symbol}"                               #   raise "Already memoized mime_type"
        end                                                                      # end
        alias #{original_method} #{symbol}                                       # alias _unmemoized_mime_type mime_type

        def #{symbol}(*args, &block)
          disabled = Tengine::Core::MethodTraceable.disabled
          begin
            Tengine::Core::stdout_logger.info("\#{self.class.name}##{symbol} called") unless disabled
            result = #{original_method}(*args, &block)
            Tengine::Core::stdout_logger.info("\#{self.class.name}##{symbol} complete") unless disabled
            return result
          rescue Exception => e
            unless e.instance_variable_get(:@__traced__) || disabled
              Tengine::Core::stderr_logger.error("\#{self.class.name}##{symbol} failure. [\#{e.class.name}] \#{e.message}\n  " << e.backtrace.join("\n  "))
              e.instance_variable_set(:@__traced__, true)
            end
            raise
          end
        end

      EOS
    end
  end

end
