# -*- coding: utf-8 -*-
require 'tengine/core'

module Tengine::Core::FindByName
  extend ActiveSupport::Concern

  class Error < Tengine::Errors::NotFound
    attr_reader :klass, :name, :options
    def initialize(klass, name, options = nil)
      @klass, @name, @options = klass, name, options
    end
    def message
      result = "#{klass.name} named #{name.inspect}"
      result << " with #{options.inspect}" if options && !options.empty?
      result << ' not found'
      result
    end
  end

  module ClassMethods
    def find_by_name(name)
      first(:conditions => {:name => name})
    end

    def find_by_name!(name, *args, &block)
      result = find_by_name(name, *args, &block)
      raise Error.new(self, name, args.last) unless result
      result
    end
  end
end
