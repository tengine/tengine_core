# -*- coding: utf-8 -*-
require 'logger'

module Tengine
  autoload :Core, 'tengine/core'
  autoload :Errors, 'tengine/errors'

  class DslError < StandardError
  end

  class << self
    def logger
      @logger ||= ::Logger.new(STDOUT)
    end
    attr_writer :logger

    def plugins
      @plugins ||= Tengine::Core::Plugins.new
    end

  end

end
