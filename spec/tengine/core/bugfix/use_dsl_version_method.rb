# -*- coding: utf-8 -*-
require 'tengine/core'

dsl_version("0.9.7")

driver :use_dsl_version_method do

  on:event01 do
    puts "using DSL version 0.9.7"
  end

end
