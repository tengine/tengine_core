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
  end

end
