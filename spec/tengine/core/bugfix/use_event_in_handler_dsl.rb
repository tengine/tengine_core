# -*- coding: utf-8 -*-
require 'tengine/core'

driver :driver01 do

  # イベントに対応する処理の実行する
  on:event01 do
    puts "#{event.key}:handler01"
  end

end
