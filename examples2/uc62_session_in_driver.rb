# -*- coding: utf-8 -*-
require 'tengine/core'

class Uc62SessionInDriver
  include Tengine::Core::Driveable

  session.update(:foo => 100) # ドライバ登録時にそのセッションに キー:foo に対して 値100 を設定する。

  on:event62
  def event62
    value = session[:foo]
    value +=1
    session.update(:foo => value)
    puts value
  end
end
