# -*- coding: utf-8 -*-
require 'tengine/core'

# sessionメソッドは、ドライバ内でのみ使用できるので、ドライバ外で使用した場合例外がraiseされる。
# loadでもbindでも途中で失敗し、Tengineコアのプロセスは終了する

session # SyntaxErrorなどではなく、Tengine::Core::DslErrorがraiseされる

driver :driver63 do

  on:event63 do
  end
end
