# -*- coding: utf-8 -*-
require 'tengine/core'

# ロード時のDSLを評価するコンテキスト。
# プラグインが拡張を行うプレースホルダです。
class Tengine::Core::DslLoadingContext
  include Tengine::Core::DslLoader

  def initialize(kernel)
    @__kernel__ = kernel
  end
end
