# -*- coding: utf-8 -*-
require 'tengine/core'

# アクティベーション時にイベントドライバを有効な状態にするかどうかを
# :enabled_on_actibation オプションで指定できる。デフォルトはtrue。

driver :driver71, :enabled_on_activation => false do

  # イベントに対応する処理の実行する
  on:event71 do
    puts "handler71"
  end

end
