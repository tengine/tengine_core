# -*- coding: utf-8 -*-
require 'tengine/core'

# アクティベーション時にEventMachineの初期化を行うことができる。

setup_eventmachine do
  puts "setup_eventmachine"
  EM.add_periodic_timer(3) do
    fire(:event72)
  end
end

driver :driver72 do
  on:event72 do
    puts "handler72"
  end
end
