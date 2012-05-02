# -*- coding: utf-8 -*-
require 'spec_helper'

describe Tengine::Core do
  describe :version do
    it "３つの数値をドットで区切った文字列" do
      Tengine::Core.version.should =~ /^\d+\.\d+\.\d+/
    end
    it "プロジェクトのルートにあるVERSIONファイルの内容と同じです" do
      Tengine::Core.version.should == File.read(File.expand_path("../../VERSION", File.dirname(__FILE__))).strip
    end
  end
end
