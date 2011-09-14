# -*- coding: utf-8 -*-
require 'tengine/core'

# これは driver62と違って、複数のプロセスが同時に数を数えても正しく+1していきます
driver :driver64 do
  session.update(:foo => 100) # ドライバ登録時にそのセッションに キー:foo に対して 値100 を設定する。

  on:event64 do
    session.update(:retry => 2) do |hash|
      hash[:foo] = hash[:foo] + 1
      # hash[:foo] += 1 # と書いても良い
    end
  end
end
