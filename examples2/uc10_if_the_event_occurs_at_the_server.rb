# -*- coding: utf-8 -*-
require 'tengine/core'

class Uc10IfTheEventOccursAtTheServer
  include Tengine::Core::Driveable
  
  # 特定のサーバからのイベントが発生した場合のみ処理を実行する
  on :event10.at("localhost")
  def event10_at_localhost
    puts "handler10 for localhost"
  end

  on :event10.at("test_server1")
  def event10_at_test_server1
    puts "handler10 for test_server1"
  end

end
