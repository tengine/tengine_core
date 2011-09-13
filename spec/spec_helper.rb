# -*- coding: utf-8 -*-
ENV["RACK_ENV"] ||= "test" # Mongoid.load!で参照しています

require 'simplecov'
SimpleCov.start if ENV["COVERAGE"]

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'rspec'
require 'tengine_core'

require 'mongoid'
Mongoid.load!(File.expand_path('mongoid.yml', File.dirname(__FILE__)))

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

RSpec.configure do |config|
  
end
