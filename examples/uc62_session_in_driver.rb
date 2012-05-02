# -*- coding: utf-8 -*-
require 'tengine/core'

# ドライバ内では sessionメソッドで取得できるセッションに対して
# updateメソッドを使ってドライバのセッションに情報を格納できる。
# 格納された情報は[]を使用して取得することができる

driver :driver62 do
  session.update(:foo => 100) # ドライバ登録時にそのセッションに キー:foo に対して 値100 を設定する。

  on:event62 do
    value = session[:foo]
    value +=1
    session.update(:foo => value)
  end
end
