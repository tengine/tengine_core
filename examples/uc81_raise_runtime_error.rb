# -*- coding: utf-8 -*-
require 'tengine/core'

driver :driver81 do

  on:event81 do
    raise RuntimeError, "by driver81"
  end

end
