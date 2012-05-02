# -*- coding: utf-8 -*-
require 'tengine/core'

driver :driver10 do

  # 特定のサーバからのイベントが発生した場合のみ処理を実行する
  on :event10.at("localhost") do
    puts "handler10 for localhost"
  end

  on :event10.at("test_server1") do
    puts "handler10 for test_server1"
  end

end
