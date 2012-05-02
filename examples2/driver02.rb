# -*- coding: utf-8 -*-
require 'tengine/core'

class Driver02
  include Tengine::Core::Driveable

  # イベントが発生したら新たなイベントを発火する
  on:event02_1
  def foo
    puts "handler02_1"
    fire(:event02_2)
  end

  on:event02_2
  def bar
    puts "handler02_2"
  end

end
