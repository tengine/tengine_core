# -*- coding: utf-8 -*-
require 'spec_helper'

require 'stringio'

describe Tengine::Core::SelectableAttr do

  module TestModule1
    class TestClass1
      include Tengine::Core::SelectableAttr
      selectable_attr :foo do
        entry 1, :a, "do"
        entry 2, :b, "re"
        entry 3, :c, "mi"
      end
      multi_selectable_attr :bar do
        entry 1, :x, "red"
        entry 2, :y, "green"
        entry 3, :z, "blue"
      end
    end
  end

  it "i18n_scopeが設定されている" do
    TestModule1::TestClass1.foo_enum.i18n_scope.should == ['selectable_attrs', 'test_module1/test_class1', 'foo']
    TestModule1::TestClass1.bar_enum.i18n_scope.should == ['selectable_attrs', 'test_module1/test_class1', 'bar']
  end


end
