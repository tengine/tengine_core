# -*- coding: utf-8 -*-
require 'tengine/core'

# アクティベーション時にイベントドライバを有効な状態にするかどうかを
# :enabled_on_actibation オプションで指定できる。デフォルトはtrue。

driver :driver70, :enabled_on_activation => true do

  on:event70 do
    puts "handler70"
  end

end
