# -*- coding: utf-8 -*-
require 'tengine/core'

class Uc71DriverDisabledOnActivation
  include Tengine::Core::Driveable
  include Tengine::Core::Driveable::ByDsl

  self.singleton_class.options = { :enabled_on_activation => false }

  # イベントに対応する処理の実行する
  on:event71
  def event71
    puts "handler71"
  end

end
