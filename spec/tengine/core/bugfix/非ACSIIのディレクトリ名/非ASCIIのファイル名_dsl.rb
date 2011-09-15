# -*- coding: utf-8 -*-
require 'tengine/core'

driver :driver_in_multibyte_path_dir do

  # イベントに対して処理Aと処理Bを実行する
  on:event01 do
    puts "handler01"
  end

end
