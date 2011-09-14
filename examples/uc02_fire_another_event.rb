# -*- coding: utf-8 -*-
require 'tengine/core'

driver :driver02 do

  # イベントが発生したら新たなイベントを発火する
  on:event02_1 do
    puts "handler02_1"
    fire(:event02_2)
  end

  on:event02_2 do
    puts "handler02_2"
  end

end
