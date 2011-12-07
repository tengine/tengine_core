# -*- coding: utf-8 -*-
require 'pathname'

module Tengine::Core::DslLoader
  include Tengine::Core::DslEvaluator

  attr_accessor :__kernel__


  # どのようなポリシーでackを返すのかをイベント種別名毎に指定できます。
  #
  # @param [Symbol] policy ackポリシー
  # @param [[Symbol/String]] args イベント種別名の配列
  #
  # 例:
  # {include:file:examples/uc50_commit_event_at_first.rb}
  #
  # 例:
  # {include:file:examples/uc51_commit_event_at_first_submit.rb}
  #
  # 例:
  # {include:file:examples/uc52_commit_event_after_all_handler_submit.rb}
  #
  def ack_policy(policy, *args)
    args.each{|arg| @__kernel__.add_ack_policy(arg, policy)}
  end

  # このメソッドにブロックを渡すことで、Tengineコアが使用するEventMachineの初期化を行うために設定を行うことができます。
  #
  # 例:
  # {include:file:examples/uc72_setup_eventmachine.rb}
  #
  def setup_eventmachine(&block)
    return unless block
    @__kernel__.em_setup_blocks << block
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
    begin
      klass.module_eval(&block)
    rescue Exception => e
      driver = klass.driver
      driver.destroy if driver && !driver.new_record?
      raise e
    end
  end

  # @see Tengine::Core::DslBinder#session
  def session
    raise Tengine::Core::DslError, "session is not available outside of event driver block." unless @__session__
    @__session_wrapper__ ||= Tengine::Core::SessionWrapper.new(@__session__)
  end


end
