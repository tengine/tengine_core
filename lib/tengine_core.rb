# -*- coding: utf-8 -*-
require 'logger'

module Tengine
  autoload :Core, 'tengine/core'

  class DslError < StandardError
  end

  class << self
    def logger
      @logger ||= ::Logger.new(STDOUT)
    end
    attr_writer :logger


    def dsl_loader_modules
      @dsl_loader_modules ||= []
    end
    def dsl_binder_modules
      @dsl_binder_modules ||= []
    end


  end

end
