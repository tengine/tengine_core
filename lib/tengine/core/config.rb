# -*- coding: utf-8 -*-
require 'tengine/core'

# require 'tengine/core/config/default' # DEFAULT定数と関係するメソッドを定義

module Tengine::Core::Config
  autoload :Core, 'tengine/core/config/core'
  autoload :Atd,  'tengine/core/config/atd'
  autoload :HeartbeatWatcher,  'tengine/core/config/heartbeat_watcher'
end
