# encoding: utf-8

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "tengine_core"
  gem.homepage = "http://github.com/tengine/tengine_core"
  gem.license = "MPL/LGPL"
  gem.summary = %Q{tengine_core is a framework/engine to support distributed processing}
  gem.description = %Q{tengine_core is a framework/engine to support distributed processing}
  gem.email = "tengine@nautilus-technologies.com"
  gem.authors = %w[saishu w-irie taigou totty hiroshinakao g-morita guemon aoetk hattori-at-nt t-yamada y-karashima akm]
  gem.bindir = 'bin'
  gem.executables = ['tengined', 'tengine_heartbeat_watchd', 'tengine_atd']
  # dependencies defined in Gemfile
end
Jeweler::RubygemsDotOrgTasks.new

require 'rspec/core'
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = FileList['spec/**/*_spec.rb']
end

RSpec::Core::RakeTask.new(:rcov) do |spec|
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rcov = true
end

task :default => :spec

require 'yard'
YARD::Rake::YardocTask.new
