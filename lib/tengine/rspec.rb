# -*- coding: utf-8 -*-
require 'tengine_core'

# Tengineのイベントドライバのテストを行うためのRSpecの拡張です
module Tengine::RSpec
  autoload :ContextWrapper, 'tengine/rspec/context_wrapper'
  autoload :Extension     , 'tengine/rspec/extension'
end
