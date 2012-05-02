# -*- coding: utf-8 -*-
require 'tengine/core'

class << Tengine
  attr_accessor :callback_for_test
end

driver :connection_test_driver do
  on :foo do
    Tengine.callback_for_test.call(:foo) if Tengine.callback_for_test
    fire :bar
  end
  on :bar do
    Tengine.callback_for_test.call(:bar) if Tengine.callback_for_test
  end
end
