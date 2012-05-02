# -*- coding: utf-8 -*-
require 'tengine/core'

# カーネルはイベントevent52_alt1を受け取ったらDBに保存。
# 対応するハンドラ群をすべて実行してすべてsubmitしたらACKを返す。
ack_policy(:after_all_handler_submit, :event52_alt1)

# このドライバでは自動テストの簡略化のために明示的に標準出力に対してputsを呼び出しています

driver :driver52_alt1_1 do
  on:event52_alt1 do
    STDOUT.puts "handler52_alt1_1 " << (ack? ? "acknowledged" : "unacknowledged")
    submit
  end
end

driver :driver52_alt1_2 do
  on:event52_alt1 do
    STDOUT.puts "handler52_alt1_2 " << (ack? ? "acknowledged" : "unacknowledged")
    # submit # submitしないのでこのDSL
  end
end

driver :driver52_alt1_3 do
  on:event52_alt1 do
    STDOUT.puts "handler52_alt1_3 " << (ack? ? "acknowledged" : "unacknowledged")
    submit
  end
end

# 上記はすべてsubmitするので通常はすべてのハンドラ実行後にACKを返す。
