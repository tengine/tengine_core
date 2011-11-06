# -*- coding: utf-8 -*-
require 'tengine/core'

class Tengine::Core::DslBindingContext
  include Tengine::Core::DslBinder

  attr_accessor :__block_bindings__

  def initialize(kernel)
    @__kernel__ = kernel
    @__block_bindings__ = {}
  end

  def __block_for__(filepath_for_bind, lineno)
    __block_bindings__[ [filepath_for_bind, lineno] ]
  end

  def __bind_block__(filepath_for_bind, lineno, &block)
    __block_bindings__[ [filepath_for_bind, lineno] ] = block
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
