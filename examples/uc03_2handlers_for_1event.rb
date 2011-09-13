# -*- coding: utf-8 -*-
require 'tengine/core'

driver :driver03 do

  # イベントに対して処理Aと処理Bを実行する

  on:event03 do
    puts "handler03_1"
  end

  on:event03 do
    puts "handler03_2"
  end

end
