# -*- coding: utf-8 -*-
# private gemserver
source "http://bts.tenginefw.com/gemserver"
source "http://rubygems.org"

# Add dependencies required to use your gem here.
# Example:
#   gem "activesupport", ">= 2.3.5"

gem "activesupport", "~> 3.1.0"
gem "activemodel"  , "~> 3.1.0"

gem "selectable_attr", "~> 0.3.14"

gem "bson"    , "~> 1.3.1"
gem "bson_ext", "~> 1.3.1"
gem "mongo"   , "~> 1.3.1"

gem "mongoid", "~> 2.2.1"

# 一般公開して、rubygems に登録するまでは、gemserver を使うようにします
gem "tengine_event", "~> 0.2.7"  #, :git => "git@github.com:tengine/tengine_event.git", :branch => "develop"

gem "daemons", "~> 1.1.4"

# Add dependencies to develop your gem here.
# Include everything needed to run rake, tests, features, etc.
group :development do
  gem "rspec", "~> 2.6.0"
  gem "factory_girl", "~> 2.1.2"
  gem "yard", "~> 0.7.2"
  gem "bundler", "~> 1.0.18"
  gem "jeweler", "~> 1.6.4"
  # gem "rcov", ">= 0"
  gem "simplecov", "~> 0.5.3"
  gem "ZenTest", "~> 4.6.2"
  gem "ci_reporter", "~>1.6.5"
end
