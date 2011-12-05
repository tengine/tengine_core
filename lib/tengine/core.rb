# -*- coding: utf-8 -*-
require 'tengine_core'
require 'logger'

module Tengine::Core
  # base
  autoload :Bootstrap        , 'tengine/core/bootstrap'
  autoload :Config           , 'tengine/core/config'
  autoload :Kernel           , 'tengine/core/kernel'
  autoload :Driveable        , 'tengine/core/driveable'
  autoload :KernelRuntime    , 'tengine/core/kernel_runtime'
  autoload :DslEvaluator     , 'tengine/core/dsl_evaluator'
  autoload :DslLoader        , 'tengine/core/dsl_loader'
  autoload :DslLoadingContext, 'tengine/core/dsl_loading_context'
  autoload :DslBinder        , 'tengine/core/dsl_binder'
  autoload :DslBindingContext, 'tengine/core/dsl_binding_context'
  autoload :DslFilterDef     , 'tengine/core/dsl_filter_def'
  autoload :Plugins          , 'tengine/core/plugins'

  # models
  autoload :Event      , 'tengine/core/event'
  autoload :Driver     , 'tengine/core/driver'
  autoload :Session    , 'tengine/core/session'
  autoload :Handler    , 'tengine/core/handler'
  autoload :HandlerPath, 'tengine/core/handler_path'
  autoload :Setting    , 'tengine/core/setting'
  autoload :Schedule   , 'tengine/core/schedule'

  # model wrappers
  autoload :EventWrapper  , 'tengine/core/event_wrapper'
  autoload :SessionWrapper, 'tengine/core/session_wrapper'

  # utilities
  autoload :CollectionAccessible, 'tengine/core/collection_accessible'
  autoload :IoToLogger          , 'tengine/core/io_to_logger'
  autoload :SelectableAttr      , 'tengine/core/selectable_attr'
  autoload :MethodTraceable     , 'tengine/core/method_traceable'
  autoload :OptimisticLock      , 'tengine/core/optimistic_lock'
  autoload :Validation          , 'tengine/core/validation'
  autoload :EventExceptionReportable, 'tengine/core/event_exception_reportable'
  autoload :FindByName          , 'tengine/core/find_by_name'

  class << self
    # Tengine::Coreの正常時の動きをアプリケーション運用者が確認できる内容を出力するロガー
    # ログレベルがinfoでも出力する内容は少ない
    def stdout_logger
      @stdout_logger ||= Logger.new(STDOUT)
    end
    attr_writer :stdout_logger

    # Tengine::Coreの異常発生時の動きをアプリケーション運用者が確認できる内容を出力するロガー
    def stderr_logger
      @stderr_logger ||= Logger.new(STDERR)
    end
    attr_writer :stderr_logger

    # リリースされたtengine_coreパッケージのバージョンを返します
    def version
      File.read(File.expand_path("../../VERSION", File.dirname(__FILE__))).strip
    end
  end

  # 設定に問題があることを示す例外
  class ConfigError < StandardError
  end

  # DSLの記述に問題があることを示す例外
  class DslError < ::Tengine::DslError
  end

  # カーネルの動作で問題が発生した場合にraiseする例外
  class KernelError < StandardError
  end


end
