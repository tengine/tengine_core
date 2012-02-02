# -*- coding: utf-8 -*-
require 'tengine/core'

class Uc08IfBothAAndBOccurs
  include Tengine::Core::Driveable

  # イベントAとイベントBが発生したら処理を実行する
  on :event08_a & :event_08_b
  def event08
    puts "handler08"
  end

end
