# -*- coding: utf-8 -*-
require 'tengine/core'

module Tengine::Core::Validation

  class Definition
    attr_reader :format, :description
    def initialize(format, description)
      @format, @description = format.freeze, description.freeze
    end
    def message
      "は#{description}でなければなりません"
    end
    def options
      {:with => format, :message => message}
    end
  end

  # ベース名
  BASE_NAME = Definition.new(
    /\A[A-Za-z_][\w\-]*\Z/,
    "英文字またはアンダースコアから始まり、英文字、アンダースコア、ハイフンまたは数字で構成される文字列").freeze

  # イベント種別名
  EVENT_TYPE_NAME = Definition.new(
    /\A[A-Za-z_][\w\-\.\:]*\Z/,
    "英文字またはアンダースコアから始まり、英文字、アンダースコア、ハイフン、ドット、コロンまたは数字で構成される文字列").freeze

  # リソース識別子
  RESOURCE_IDENTIFIER_PROTOCOL_FORMAT = /\A\w+\Z/.freeze
  RESOURCE_IDENTIFIER = Definition.new(
    /\A#{RESOURCE_IDENTIFIER_PROTOCOL_FORMAT.source}:#{BASE_NAME.format.source}(?:\/#{BASE_NAME.format.source})*\Z/,
    "'プロトコル:要素1/要素2/.../要素N'という構造を持つ文字列(プロトコルは英数字あるいはアンダースコア、要素は英数字あるいはアンダースコアかハイフン)"
    ).freeze

end
