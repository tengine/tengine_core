# -*- coding: utf-8 -*-
require 'tengine/core'

driver :driver08 do

  # イベントAとイベントBが発生したら処理を実行する
  on :event08_a & :event_08_b do
    puts "handler08"
  end

end
