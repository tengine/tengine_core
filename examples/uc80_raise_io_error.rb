# -*- coding: utf-8 -*-
require 'tengine/core'

driver :driver80 do

  on:event80 do
    raise IOError, "by driver80"
  end

end
