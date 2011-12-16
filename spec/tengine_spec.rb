# -*- coding: utf-8 -*-
require 'spec_helper'

require 'logger'

describe Tengine do
  describe :logger do
    it "is either Logger, or NullLogger" do
      # FIXME: write a custom matcher for "either X or Y".
      [Logger, Tengine::NullLogger].should include(Tengine.logger.class)
    end
  end

end
