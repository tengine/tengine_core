# -*- coding: utf-8 -*-
require 'tengine/core'

# カーネルはイベントevent50を受け取ったらDBに保存して、すぐにキューにACKを返す。
# 特に指定しない場合、カーネルはこの :at_first が指定されているように振る舞う。
ack_policy(:at_first, :event50)

# このドライバでは自動テストの簡略化のために明示的に標準出力に対してputsを呼び出しています

driver :driver50 do

  on:event50 do
    STDOUT.puts "handler50 " << (ack? ? "acknowledged" : "unacknowledged")
    submit # submitしても無視されます
  end

end
