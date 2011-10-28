# -*- coding: utf-8 -*-
require 'pathname'

module Tengine::Core::DslLoader
  include Tengine::Core::DslEvaluator

  # @see Tengine::Core::DslBinder#ack_policy
  def ack_policy(*args)
    # DBにack_policyを登録する訳ではないのでここでは何もしません
  end

  # @see Tengine::Core::DslBinder#setup_eventmachine
  def setup_eventmachine(&block)
  end

  # イベントドライバを登録します。
  #
  # イベントドライバはonメソッドで定義されるイベントハンドラを持つことができます。
  # イベントドライバは実行時のユーザーによる有効化、無効化の対象になります。
  # 無効化されたイベントドライバのイベントハンドラは、イベントが発生した際に
  # それがフィルタにマッチしたとしても、その処理を実行しません。
  # つまりイベントハンドラの有効化、無効化は、それをまとめているイベントドライバ毎に
  # 指定することが可能です。
  #
  # @param [String] name イベントドライバ名
  # @param [Hash] options オプション
  # @option options [String] :enabled_on_activation 実行時に有効にするならばtrue、でなければfalse。デフォルトはtrue
  # @return [Tengine::Core::Driver]
  # @see #on
  #
  # 例:
  # {include:file:examples/uc01_execute_processing_for_event.rb}
  def driver(name, options = {}, &block)
    drivers = Tengine::Core::Driver.where(:name => name.to_s, :version => config.dsl_version)
    # 指定した version の driver が見つかった場合にはデプロイ済みなので以降の処理は行わず処理を終了する
    driver = drivers.first
    if driver
      Tengine::Core::stdout_logger.warn("driver#{name.to_s.dump}は既に登録されています")
      # @__driver__ = driver # ここでインスタンス変数に入れてもブロックを評価しないので使われません。
    else
      driver = Tengine::Core::Driver.new(options.update({
          :name => name,
          :version => config.dsl_version,
          :enabled => !config[:tengined][:skip_enablement],   # driverを有効化して登録するかのオプション
          :enabled_on_activation => options[:enabled_on_activation].nil? || options[:enabled_on_activation],  # DSLに記述されているオプション
          }))
      driver.create_session
      __safety_driver__(driver, &block)
      driver.save!
    end
    driver
  end

  # イベントドライバにイベントハンドラを登録します。
  #
  # このメソッドは、driverメソッドに渡されたブロックの中で使用する必要があります。
  #
  # @param [String/Symbol/Tengine::Core::DslFilterDef] filter_def ハンドリングするイベント種別名、あるいはそれらの組み合わせ。
  # @return [Tengine::Core::Handler]
  # @see #driver
  #
  # filter_defとして複合した条件を記述することも可能です。
  # {include:file:examples/uc08_if_both_a_and_b_occurs.rb}
  def on(filter_def, options = {}, &block)
    event_type_names = filter_def.respond_to?(:event_type_names) ? filter_def.event_type_names : [filter_def.to_s]
    filepath, lineno = *__source_location__(block)
    @__driver__.handlers.new(
      # filepathはTengineコアが動く環境ごとに違うかもしれないので、相対パスを使う必要があります。
      :filepath => config.relative_path_from_dsl_dir(filepath),
      :lineno => lineno,
      :event_type_names => event_type_names,
      :filter => filter_def.is_a?(Tengine::Core::DslFilterDef) ? filter_def.filter : nil)
    # 一つのドライバに対して複数個のハンドラを登録しようとした際に警告を出すべきだが・・・
    # Tengine::Core::stdout.warn("driver#{@__driver__.name.dump}には、同一のevent_type_name#{event_type_name.to_s.dump}が複数存在します")
  end

  # @see Tengine::Core::DslBinder#session
  def session
    raise Tengine::Core::DslError, "session is not available outside of event driver block." unless @__session__
    @__session_wrapper__ ||= Tengine::Core::SessionWrapper.new(@__session__)
  end

  # @see Tengine::Core::DslBinder#event
  def event
    raise Tengine::Core::DslError, "event is not available outside of event handler block."
  end

  # @see Tengine::Core::DslBinder#submit
  def submit
    raise Tengine::Core::DslError, "submit is not available outside of event handler block."
  end


end
