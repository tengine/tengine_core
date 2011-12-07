# -*- coding: utf-8 -*-
ENV["RACK_ENV"] ||= "test" # Mongoid.load!で参照しています

require 'simplecov'
SimpleCov.start if ENV["COVERAGE"]

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'rspec'
require 'factory_girl'

require 'tengine_core'
require 'mongoid'
Mongoid.load!(File.expand_path('mongoid.yml', File.dirname(__FILE__)))

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

Tengine::Core::MethodTraceable.disabled = true
require 'logger'
log_path = File.expand_path("../tmp/log/test.log", File.dirname(__FILE__))
Tengine.logger = Logger.new(log_path)
Tengine.logger.level = Logger::DEBUG
Tengine::Core.stdout_logger = Logger.new(log_path)
Tengine::Core.stdout_logger.level = Logger::DEBUG
Tengine::Core.stderr_logger = Logger.new(log_path)
Tengine::Core.stderr_logger.level = Logger::DEBUG

Tengine::Core::Kernel.event_exception_reporter = :raise_all

RSpec.configure do |config|
  config.include Factory::Syntax::Methods
end

Dir["#{File.expand_path('factories', File.dirname(__FILE__))}/**/*.rb"].each {|f| require f}
