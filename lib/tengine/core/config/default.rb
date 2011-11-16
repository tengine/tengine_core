# -*- coding: utf-8 -*-
require 'tengine/core/config'

# このファイルはlib/tengine/core/config.rb で定義しているTengine::Core::Configに
# 定数DEFAULTとそれにまつわるクラスメソッドを追加しているだけで、
# クラスやモジュールを新たに定義することはありません

class Tengine::Core::Config
  class << self
    def default_hash
      copy_deeply(DEFAULT, {}, true)
    end

    def copy_deeply(source, dest, copy_if_nil = false)
      source.each do |key, value|
        case value
        when NilClass then
          dest[key] = nil if copy_if_nil
        when TrueClass, FalseClass, Numeric, Symbol then
          dest[key] = value
        when Hash then
          dest[key] = copy_deeply(value, dest[key] || {}, copy_if_nil)
        else
          dest[key] = value.dup
        end
      end
      dest
    end

    def skelton_hash
      clear_values_deeply(default_hash)
    end

    def clear_values_deeply(hash)
      hash.each do |key, value|
        case value
        when Hash then
          clear_values_deeply(hash[key])
        else
          hash[key] = nil
        end
      end
    end
  end

  # このデフォルト値をdupしたものを、起動時のオプションを格納するツリーとして使用します
  DEFAULT = {
    :action => "start", # 設定ファイルには記述しない
    :config => nil,     # 設定ファイルには記述しない

    :tengined => {
      :daemon => false,
      # :prevent_loader    => nil, # デフォルトなし。設定ファイルには記述しない
      # :prevent_enabler   => nil, # デフォルトなし。設定ファイルには記述しない
      # :prevent_activator => nil, # デフォルトなし。設定ファイルには記述しない
      :activation_timeout => 300,
      # :load_path => "/var/lib/tengine", # 必須
      :pid_dir        => "./tmp/tengined_pids"       , # 本番環境での例 "/var/run/tengined_pids"
      :status_dir     => "./tmp/tengined_status"     , # 本番環境での例 "/var/run/tengined_status"
      :activation_dir => "./tmp/tengined_activations", # 本番環境での例 "/var/run/tengined_activations"
      :heartbeat_period => 0, # GRハートビートの送信周期。デフォルトではGRハートビートは無効
      :confirmation_threshold => 'info' # デフォルトではinfo以下のイベントはイベント登録時に自動でconfirmedがtrueになります
    }.freeze,

    :db => {
      :host => 'localhost',
      :port => 27017,
      :username => nil,
      :password => nil,
      :database => 'tengine_production',
    }.freeze,

    :event_queue => {
      :connection => {
        :host => 'localhost',
        :port => 5672,
        # :vhost => nil, # デフォルトなし。
        # :user  => nil, # デフォルトなし。
        # :pass  => nil, # デフォルトなし。
      }.freeze,
      :exchange => {
        :name => 'tengine_event_exchange',
        :type => 'direct',
        :durable => true,
      }.freeze,
      :queue => {
        :name => 'tengine_event_queue',
        :durable => true,
      }.freeze,
    }.freeze,

    :log_common => {
      :output        => nil        , # file path or "STDOUT" / "STDERR"
      :rotation      => 3          , # rotation file count or daily,weekly,monthly. default: 3
      :rotation_size => 1024 * 1024, # number of max log file size. default: 1048576 (10MB)
      :level         => 'info'     , # debug/info/warn/error/fatal. default: info
    }.freeze,

    :application_log => {
      :output        => nil, # file path or "STDOUT" / "STDERR". default: if daemon process then "./log/application.log" else "STDOUT"
      :rotation      => nil, # rotation file count or daily,weekly,monthly. default: value of --log-common-rotation
      :rotation_size => nil, # number of max log file size. default: value of --log-common-rotation-size
      :level         => nil, # debug/info/warn/error/fatal. default: value of --log-common-level
    }.freeze,

    :process_stdout_log => {
      :output        => nil, # file path or "STDOUT" / "STDERR". default: if daemon process then "./log/#{$PROGRAM_NAME}_#{Process.pid}_stdout.log" else "STDOUT"
      :rotation      => nil, # rotation file count or daily,weekly,monthly. default: value of --log-common-rotation
      :rotation_size => nil, # number of max log file size. default: value of --log-common-rotation-size
      :level         => nil, # debug/info/warn/error/fatal. default: value of --log-common-level
    }.freeze,

    :process_stderr_log => {
      :output        => nil, # file path or "STDOUT" / "STDERR". default: if daemon process then "./log/#{$PROGRAM_NAME}_#{Process.pid}_stderr.log" else "STDERR"
      :rotation      => nil, # rotation file count or daily,weekly,monthly. default: value of --log-common-rotation
      :rotation_size => nil, # number of max log file size. default: value of --log-common-rotation-size
      :level         => nil, # debug/info/warn/error/fatal. default: value of --log-common-level
    }.freeze,

    # tengine_docs/source/architechture_design/core.rst
    :heartbeat => {
      :core => {
        :interval => 30,
        :expire => 120,
      }.freeze,
      :job => {
        :interval => 5,
        :expire => 20,
      }.freeze,
      :hbw => {
        :interval => 30,
        :expire => 120,
      }.freeze,
      :resourcew => {
        :interval => 30,
        :expire => 120,
      }.freeze,
      :atd => {
        :interval => 30,
        :expire => 120,
      }.freeze,
    }.freeze,
  }.freeze
end
