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
    unless block_given?
      # Tengine::Core::stdout.info("no block given at #{caller.first}")
      return
    end

    if dsl_version_document = Tengine::Core::Setting.first(:conditions => {:name => "dsl_version"})
      dsl_version_document.value = config.dsl_version
      dsl_version_document.save!
    else
      Tengine::Core::Setting.create!(:name => "dsl_version", :value => config.dsl_version)
    end
    c = config
    klass = Class.new
    const_name = name.to_s.camelize
#     if Object.constants.include?(const_name) || defined?(const_name)
#       puts "#{const_name} is already defined\n  " << caller.join("\n  ")
#     end
    Object.const_set(const_name, klass)
    klass.module_eval do
      include Tengine::Core::Driveable::ByDsl
      self.singleton_class.config = c
      self.singleton_class.options = options
      include Tengine::Core::Driveable
    end
    klass.module_eval(&block)
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
    unless block_given?
      # Tengine::Core::stdout.info("no block given at #{caller.first}")
      return
    end
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
