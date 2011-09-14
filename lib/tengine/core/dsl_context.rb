# -*- coding: utf-8 -*-
require 'tengine/core'

class Tengine::Core::DslContext
  include Tengine::Core::DslBinder

  attr_accessor :__block_bindings__

  def initialize(kernel)
    @__kernel__ = kernel
    @__block_bindings__ = {}
  end

  def __block_for__(handler)
    __block_bindings__[handler.id.to_s]
  end

  def __bind_blocks_for_handler_id__(handler, &block)
    __block_bindings__[handler.id.to_s] = block
  end

  # デバッグ用の情報を表示します
  def to_a
    __block_bindings__.inject({}){|d, (handler_id, block)|
      f, l = block.source_location
      d["#{f}:#{l}"] = handler_id
      d
    }
  end

end
