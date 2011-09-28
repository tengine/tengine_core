# -*- coding: utf-8 -*-
require 'spec_helper'

require 'logger'

describe Tengine do
  describe :logger do
    it do
      Tengine.logger.should be_a(Logger)
    end
  end

end
