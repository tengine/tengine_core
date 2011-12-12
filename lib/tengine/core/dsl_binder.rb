# -*- coding: utf-8 -*-
require 'tengine/core'

require 'eventmachine'
require 'tengine/event'

module Tengine::Core::DslBinder
  include Tengine::Core::DslEvaluator

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

  # @see Tengine::Core::DslLoader#driver
  def driver(name, options = {}, &block)
    unless block_given?
      # Tengine::Core::stdout.info("no block given at #{caller.first}")
      return
    end
    drivers = Tengine::Core::Driver.where(:name => name, :version => config.dsl_version)
    # 指定した version の driver が見つからなかった場合にはデプロイされていないのでエラー
    driver = drivers.first
    if driver
      __safety_driver__(driver, &block)
    else
      raise Tengine::Core::KernelError, "DSL Version mismatch. #{config.dsl_version}"
    end
    driver
  end

  # @see Tengine::Core::DslLoader#on
  def on(event_type_name, options = {}, &block)
    unless block_given?
      # Tengine::Core::stdout.info("no block given at #{caller.first}")
      return
    end
    filepath, lineno = *__source_location__(block)
    conditions = {
      :filepath => config.relative_path_from_dsl_dir(filepath),
      :lineno => lineno
    }
    handler = @__driver__.handlers.find(:first, :conditions => conditions)
    # 古い（なのに同じバージョンを使用している）Driverにはないハンドラが登録された場合は開発環境などでは十分ありえる
    if handler.nil?
      raise Tengine::Core::KernelError, "Tengine::Core::Handler not found for #{conditions.inspect}\nhandlers are\n    " << @__driver__.handlers.map(&:inspect).join("\n    ")
    end
    __bind_blocks_for_handler_id__(handler, &block)
  end

  # イベントを発火します。
  #
  # @param [String/Symbol] event_type_name このメソッドによって発火されるイベントのイベント種別名。
  # @param [Hash] options オプション
  # @option options [String] :key イベントを一意に識別するための文字列。デフォルトはUUIDによる値。
  # @option options [String] :source_name イベントの発生源名。デフォルトはホスト名とPID。
  # @option options [Time] :occurred_at イベントの発生日時。デフォルトは現在時刻
  # @option options [Integer] :level 通知レベルの値のいずれか。1-5の値のいずれか。デフォルトは2。
  # @option options [Symbol] :level_key 通知レベルのSymbol表現 :debug :info :warn :error :fatalのいずれか。デフォルトは:info
  # @option options [String] :sender_name 送信者名。デフォルトはホスト名とPID。
  # @option options [Hash] :properties プロパティ。任意の名前と値を指定することができる。
  # @return [Tengine::Event]
  #
  # @see Tengine::Event::Sender#fire
  #
  # 例:
  # {include:file:examples/uc02_fire_another_event.rb}
  #
  def fire(event_type_name, options = {})
    @__kernel__.sender.fire(event_type_name, options)
  end

  # セッションを返します。
  #
  # セッションはイベントハンドラ外のスコープでデータを保持するため、複数のイベントで使用するデータを
  # 格納するために使用することができます。
  #
  # @return [Tengine::Core::Session]
  #
  # sessionメソッドは、イベントハンドラに渡されたブロックの中だけでなく、
  # driverに渡されたブロックの中で使用することができるため、セッションに格納されるデータを初期化することが可能です。
  #
  # 例:
  # {include:file:examples/uc62_session_in_driver.rb}
  #
  def session
    raise Tengine::Core::DslError, "session is not available outside of event driver block." unless @__session__
    if @__kernel__.processing_event?
      @__session_in_processing_event__ ||= Tengine::Core::SessionWrapper.new(@__session__)
    else
      # onの外ではDslLoaderがデータの操作を行うので、DslBinderはイベント処理中じゃなかったら更新はしません。
      @__session_wrapper__ ||= Tengine::Core::SessionWrapper.new(@__session__, :ignore_update => true)
    end
  end

  # イベントを返します。
  #
  # このメソッドはイベントハンドラに渡されたブロックの中で使用できます。
  #
  # @return [Tengine::Core::Event]
  def event
    raise Tengine::Core::DslError, "event is not available outside of event handler block." unless @__kernel__.processing_event?
    @__event_wrapper__ ||= Tengine::Core::EventWrapper.new(@__event__)
  end

  # イベントが送られたキューに対してackが返されているかどうかを返します。
  #
  # @return [ture/false]
  def ack?
    @__kernel__.ack?
  end

  # イベントが送られたキューに対して、ackを返し、処理が完了したことを通知します
  def submit
    raise Tengine::Core::DslError, "submit is not available outside of event handler block." unless @__kernel__.processing_event?
    @__kernel__.submit
  end

  # 現時点ではMM1との互換性のためのダミーのメソッドです
  # 必要があれば将来ちゃんと役割を見直して復活するかもしれません
  def dsl_version(*args)
  end

end
