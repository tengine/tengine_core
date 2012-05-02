# -*- coding: utf-8 -*-
require 'tengine_core'

module Tengine::Errors

  # Tengineが提供するAPIによってデータが見つからないことを示す例外です。
  # railsの場合、ActionDispatch::ShowExceptions.rescue_responses を使って
  # 以下のように設定して使用することを想定しています。
  #
  # ActionDispatch::ShowExceptions.rescue_responses.update({
  #   "Tengine::Errors::NotFound" => :not_found,
  # })
  #
  # see http://d.hatena.ne.jp/takihiro/20100318/1268864801
  class NotFound < StandardError
  end

end
