# -*- coding: utf-8 -*-
require 'tengine/core'

# カーネルはイベントevent51を受け取ったらDBに保存。
# 対応するハンドラを実行して最初にsubmitされたときにACKを返す。
ack_policy(:at_first_submit, :event51)

class Uc51CommitEventAtFirstSubmit_1
  include Tengine::Core::Driveable

  # 最初に実行されるハンドラではsubmitしないので、ACKされない
  on:event51
  def event51
    puts "handler51_1"
  end
end
