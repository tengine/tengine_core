# -*- coding: utf-8 -*-
require 'tengine/core'

# カーネルはイベントevent52を受け取ったらDBに保存。
# 対応するハンドラ群をすべて実行してすべてsubmitしたらACKを返す。
ack_policy(:after_all_handler_submit, :event52)

# このドライバでは自動テストの簡略化のために明示的に標準出力に対してputsを呼び出しています

driver :driver52_1 do
  on:event52 do
    STDOUT.puts "handler52_1 " << (ack? ? "acknowledged" : "unacknowledged")
    submit
  end
end

driver :driver52_2 do
  on:event52 do
    STDOUT.puts "handler52_2 " << (ack? ? "acknowledged" : "unacknowledged")
    submit
  end
end

driver :driver52_3 do
  on:event52 do
    STDOUT.puts "handler52_3 " << (ack? ? "acknowledged" : "unacknowledged")
    submit
  end
end

# 上記はすべてsubmitするので通常はすべてのハンドラ実行後にACKを返す。
