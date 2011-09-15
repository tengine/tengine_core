# -*- coding: utf-8 -*-
require 'spec_helper'

describe "" do
  before do
    Tengine::Core::Driver.delete_all
    Tengine::Core::Session.delete_all
    @config = Tengine::Core::Config.new({
        :tengined => {
          :load_path => File.expand_path('非ACSIIのディレクトリ名/非ASCIIのファイル名_dsl.rb', File.dirname(__FILE__)),
        },
      })
  end

  it "aとbが両方起きたらハンドラが実行されます" do
    @bootstrap = Tengine::Core::Bootstrap.new(@config)
    @bootstrap.load_dsl
    @kernel = Tengine::Core::Kernel.new(@config)
    @kernel.bind
  end
end
