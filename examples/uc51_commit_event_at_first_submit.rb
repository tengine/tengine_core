# -*- coding: utf-8 -*-
require 'tengine/core'

# カーネルはイベントevent51を受け取ったらDBに保存。
# 対応するハンドラを実行して最初にsubmitされたときにACKを返す。
ack_policy(:at_first_submit, :event51)

driver :driver51_1 do
  # 最初に実行されるハンドラではsubmitしないので、ACKされない
  on:event51 do
    puts "handler51_1"
  end
end

driver :driver51_2 do
  # このハンドラでsubmitするので、ACKする
  on:event51 do
    puts "handler51_2"
    submit
  end
end

driver :driver51_3 do
  # このハンドラでsubmitするが、すでにACKしているのでACKしない
  on:event51 do
    puts "handler51_3"
    submit
  end
end
