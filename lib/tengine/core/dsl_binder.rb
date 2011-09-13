# -*- coding: utf-8 -*-
require 'tengine/core'

require 'tengine/event'

module Tengine::Core::DslBinder
  include Tengine::Core::DslEvaluator

  def ack_policy(policy, *args)
    args.each{|arg| @__kernel__.add_ack_policy(arg, policy)}
  end

  def ack?; @__kernel__.ack?; end
  def submit; @__kernel__.submit; end

  def driver(name, options = {}, &block)
    drivers = Tengine::Core::Driver.where(:name => name, :version => config.dsl_version)
    # 指定した version の driver が見つからなかった場合にはデプロイされていないのでエラー
    driver = drivers.first
    if driver
      __safety_driver__(driver, &block)
    else
      raise Tengine::Core::VersionError, "version mismatch. #{config.dsl_version}"
    end
    driver
  end

  def on(event_type_name, options = {}, &block)
    filepath, lineno = *block.source_location
    handlers = @__driver__.handlers.where(
      :filepath => config.relative_path_from_dsl_dir(filepath),
      :lineno => lineno).to_a
    # 古い（なのに同じバージョンを使用している）Driverにはないハンドラが登録された場合は開発環境などでは十分ありえる
    if handlers.empty?
      # TODO こういう場合の例外は何を投げるべき？
      raise "Handler not found for #{filepath}:#{lineno}"
    end
    handlers.each do |handler|
      __bind_blocks_for_handler_id__(handler, &block)
    end
  end

  def fire(event_type_name, options = {})
    Tengine::Event.config = {
      :connection => config[:event_queue][:connection],
      :exchange => config[:event_queue][:exchange],
      :queue => config[:event_queue][:queue]
    }
    Tengine::Event.fire(event_type_name, options)
  end

  def session
    if @__kernel__.processing_event?
      @__session_in_processing_event__ ||= Tengine::Core::SessionWrapper.new(@__session__)
    else
      # onの外ではDslLoaderがデータの操作を行うので、DslBinderはイベント処理中じゃなかったら更新はしません。
      @__session_wrapper__ ||= Tengine::Core::SessionWrapper.new(@__session__, :ignore_update => true)
    end
  end

  def event
    if @__kernel__.processing_event?
      @__session_in_processing_event__ ||= Tengine::Core::EventWrapper.new(@__event__)
    else
      raise "no evnet"
    end
  end

end
