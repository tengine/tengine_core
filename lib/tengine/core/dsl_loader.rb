# -*- coding: utf-8 -*-
require 'pathname'

module Tengine::Core::DslLoader
  include Tengine::Core::DslEvaluator

  def ack_policy(*args)
    # DBにack_policyを登録する訳ではないのでここでは何もしません
  end

  def driver(name, options = {}, &block)
    drivers = Tengine::Core::Driver.where(:name => name.to_s, :version => config.dsl_version)
    # 指定した version の driver が見つかった場合にはデプロイ済みなので以降の処理は行わず処理を終了する
    driver = drivers.first
    if driver
      Tengine::Core::stdout_logger.warn("driver#{name.to_s.dump}は既に登録されています")
      # @__driver__ = driver # ここでインスタンス変数に入れてもブロックを評価しないので使われません。
    else
      driver = Tengine::Core::Driver.new((options || {}).update({
          :name => name,
          :version => config.dsl_version,
          :enabled => !config[:tengined][:skip_enablement],   # driverを有効化して登録するかのオプション
          }))
      driver.create_session
      __safety_driver__(driver, &block)
      driver.save!
    end
    driver
  end

  def on(filter_def, options = {}, &block)
    event_type_names = filter_def.respond_to?(:event_type_names) ? filter_def.event_type_names : [filter_def.to_s]
    filepath, lineno = *block.source_location
    @__driver__.handlers.new(
      # filepathはTengineコアが動く環境ごとに違うかもしれないので、相対パスを使う必要があります。
      :filepath => config.relative_path_from_dsl_dir(filepath),
      :lineno => lineno,
      :event_type_names => event_type_names,
      :filter => filter_def.is_a?(Tengine::Core::DslFilterDef) ? filter_def.filter : nil)
    # 一つのドライバに対して複数個のハンドラを登録しようとした際に警告を出すべきだが・・・
    # Tengine::Core::stdout.warn("driver#{@__driver__.name.dump}には、同一のevent_type_name#{event_type_name.to_s.dump}が複数存在します")
  end

  def session
    @__session_wrapper__ ||= Tengine::Core::SessionWrapper.new(@__session__)
  end


end
