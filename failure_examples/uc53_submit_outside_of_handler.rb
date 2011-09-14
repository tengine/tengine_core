# -*- coding: utf-8 -*-
require 'tengine/core'

# submitメソッドは、ハンドラ内でのみ使用できるので、ハンドラ外で使用した場合例外がraiseされる。
# loadでもbindでも途中で失敗し、Tengineコアのプロセスは終了する
ack_policy(:at_first, :event53)

driver :driver53 do
  submit # SyntaxErrorなどではなく、Tengine::Core::DslErrorがraiseされる

  on:event53 do
    puts "handler53"
  end

end
