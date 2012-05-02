# -*- coding: utf-8 -*-
require 'tengine/core'

# eventメソッドはハンドラ内でのみ使用できるものなのでその外で使用したら例外がraiseされる。
# loadでもbindでも途中で失敗し、Tengineコアのプロセスは終了する

driver :driver61 do
  event # SyntaxErrorではなく、Tengine::Core::DslErrorがraiseされる

  on:event61 do
  end
end
