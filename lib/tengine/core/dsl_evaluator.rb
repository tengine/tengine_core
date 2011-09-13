# -*- coding: utf-8 -*-
require 'tengine/core'

module Tengine::Core::DslEvaluator
  attr_accessor :config

  def __evaluate__
    __setup_core_ext__
    begin
      Tengine::Core.stdout_logger.debug("dsl_file_paths:\n  " << config.dsl_file_paths.join("\n  "))
      config.dsl_file_paths.each { |f| self.instance_eval(File.read(f), f) }
    ensure
      __teardown_core_ext__
    end
  end

  def __safety_event__(event)
    @__event__ = event
    begin
      yield if block_given?
    ensure
      @__event__ = nil
    end
  end

  def __safety_driver__(driver)
    @__driver__ = driver
    @__session__ = driver.session
    begin
      yield if block_given?
    ensure
      @__driver__ = nil
      @__session__ = nil
    end
  end

  private

  def __setup_core_ext__
    Symbol.class_eval do
      def and(other)
        Tengine::Core::DslFilterDef.new(
          [self.to_s, other.to_s],
          {
            'method' => :and,
            'children' => [
              { 'pattern' => self, 'method' => :find_or_mark_in_session },
              { 'pattern' => other, 'method' => :find_or_mark_in_session },
            ]
          })
      end
      alias_method :&, :and
    end
  end

  def __teardown_core_ext__
    Symbol.class_eval do
      remove_method(:&, :and)
    end
  end
end
