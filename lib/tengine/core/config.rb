# -*- coding: utf-8 -*-
require 'tengine/core'
require 'logger'

require 'active_support/core_ext/hash'
require 'active_support/ordered_hash'
require 'active_support/hash_with_indifferent_access'
require 'active_support/memoizable'

class Tengine::Core::Config
  # memoize については http://wota.jp/ac/?date=20081025#p11 などを参照してください
  extend ActiveSupport::Memoizable

  def initialize(original= nil)
    @hash = ActiveSupport::HashWithIndifferentAccess.new(self.class.default_hash)
    original = ActiveSupport::HashWithIndifferentAccess.new(original || {})
    # 設定ファイルが指定されている場合はそれをロードする
    if config_filepath = original[:config]
      begin
        hash = YAML.load_file(config_filepath)
      rescue Exception => e
        # File.exist?を使うとモックを使ったテストが面倒になるので例外をrescueしています。
        raise Tengine::Core::ConfigError, "Exception occurred when loading configuration file: #{config_filepath}. #{e.message}"
      end
      hash = ActiveSupport::HashWithIndifferentAccess.new(hash)
      self.class.copy_deeply(hash, @hash)
    end
    self.class.copy_deeply(original, @hash)
    @dsl_load_path_type = :unknown
  end

  def [](key)
    @hash[key]
  end

  def dsl_load_path
    self[:tengined][:load_path]
  end
  memoize :dsl_load_path

  def dsl_dir_path
    # RSpecで何度もモックを作らなくていいようにDir.exist?などを最小限にする
    case @dsl_load_path_type
    when :dir  then File.expand_path(dsl_load_path)
    when :file then File.expand_path(File.dirname(dsl_load_path))
    else
      if Dir.exist?(dsl_load_path)
        @dsl_load_path_type = :dir
        File.expand_path(dsl_load_path)
      elsif File.exist?(dsl_load_path)
        @dsl_load_path_type = :file
        File.expand_path(File.dirname(dsl_load_path))
      else
        raise Tengine::Core::ConfigError, "file or directory doesn't exist. #{dsl_load_path}"
      end
    end
  end
  memoize :dsl_dir_path


  def dsl_file_paths
    # RSpecで何度もモックを作らなくていいようにDir.exist?などを最小限にする
    case @dsl_load_path_type
    when :dir  then Dir.glob("#{dsl_dir_path}/**/*.rb")
    when :file then [dsl_load_path]
    else
      if Dir.exist?(dsl_load_path)
        @dsl_load_path_type = :dir
        Dir.glob("#{dsl_dir_path}/**/*.rb")
      elsif File.exist?(dsl_load_path)
        @dsl_load_path_type = :file
        [dsl_load_path]
      else
        raise Tengine::Core::ConfigError, "file or directory doesn't exist. #{dsl_load_path}"
      end
    end
  end
  memoize :dsl_file_paths

  def dsl_version_path
    File.expand_path("VERSION", dsl_dir_path)
  end
  memoize :dsl_version_path

  def dsl_version
    File.exist?(dsl_version_path) ? File.read(dsl_version_path).strip : Time.now.strftime("%Y%m%d%H%M%S")
  end
  memoize :dsl_version

  def relative_path_from_dsl_dir(filepath)
    path = Pathname.new(filepath)
    path.relative? ? path.to_s : path.relative_path_from(Pathname.new(dsl_dir_path)).to_s
  end

  def status_dir
    self[:tengined][:status_dir]
  end
  memoize :status_dir

  def activation_dir
    self[:tengined][:activation_dir]
  end
  memoize :activation_dir

  def confirmation_threshold
    Tengine::Event::LEVELS_INV[ self[:tengined][:confirmation_threshold].to_sym ]
  end
  memoize :confirmation_threshold

  def heartbeat_period
    self[:tengined][:heartbeat_period].to_i
  end

  def heartbeat_enabled?
    heartbeat_period > 0
  end

  def setup_loggers
    stdout_path = log_config(:process_stdout_log)[:output]
    $stdout = File.open(stdout_path, "w") unless stdout_path =~ /^STDOUT$|^STDERR$/
    stderr_path = log_config(:process_stderr_log)[:output]
    $stderr = File.open(stderr_path, "w") unless stderr_path =~ /^STDOUT$|^STDERR$/
    Tengine::Core::stdout_logger = new_logger(:process_stdout_log, $stdout)
    Tengine::Core::stderr_logger = new_logger(:process_stderr_log, $stdout)
    Tengine.logger = new_logger(:application_log)
    Tengine::Core::stdout_logger.info("#{self.class.name}#setup_loggers complete")
  rescue Exception
    Tengine::Core::stderr_logger.info("#{self.class.name}#setup_loggers failure")
    raise
  end

  def new_logger(log_type_name, output = nil)
    raise_unless_valid_log_type_name(log_type_name)
    c = log_config(log_type_name)
    output = output || c[:output]
    result = Logger.new(output_to_io_or_filepath(output), c[:rotation], c[:rotation_size])
    result.formatter = logger_formatters(log_type_name)
    result.level = Logger.const_get(c[:level].to_s.upcase)
    result
  end

  def log_config(log_type_name)
    raise_unless_valid_log_type_name(log_type_name)
    log_common = self[:log_common].dup
    log_config = self[log_type_name].dup
    log_config.delete_if{|key, value| value.nil?}
    result = {}
    result.update(log_common)
    result.update(log_config)
    result.symbolize_keys!
    result.delete(:rotation_size) unless result[:rotation].is_a?(Integer)
    result[:output] ||= default_log_output(log_type_name, !self[:tengined][:daemon])
    result
  end

  private

  LOG_TYPE_NAMES = [:application_log, :process_stdout_log, :process_stderr_log].freeze

  def raise_unless_valid_log_type_name(log_type_name)
    raise ArgumentError, "Unsupported log_type_name: #{log_type_name.inspect}" unless LOG_TYPE_NAMES.include?(log_type_name)
  end

  def default_log_output(log_type_name, foreground)
    raise_unless_valid_log_type_name(log_type_name)
    case log_type_name
    when :application_log then foreground ? 'STDOUT' : "./log/application.log"
    when :process_stdout_log then foreground ? 'STDOUT' : "./log/#{File.basename($PROGRAM_NAME)}_#{Process.pid}_stdout.log"
    when :process_stderr_log then foreground ? 'STDERR' : "./log/#{File.basename($PROGRAM_NAME)}_#{Process.pid}_stderr.log"
    end
  end

  def output_to_io_or_filepath(output)
    @output_to_io_or_filepath ||= {"STDOUT" => STDOUT, "STDERR" => STDERR}.freeze
    @output_to_io_or_filepath[output] || output
  end

  def logger_formatters(log_type_name)
    @process_identifier ||= "#{File.basename($PROGRAM_NAME)}<#{Process.pid}>".freeze
    @logger_formatters ||= {
      :application_log    => lambda{|level, t, prog, msg| "#{t.iso8601} #{level} #{@process_identifier} #{msg}\n"},
      :process_stdout_log => lambda{|level, t, prog, msg| "#{t.iso8601} STDOUT #{@process_identifier} #{msg}\n"},
      :process_stderr_log => lambda{|level, t, prog, msg| "#{t.iso8601} STDERR #{@process_identifier} #{msg}\n"}
    }.freeze
    @logger_formatters[log_type_name]
  end


  public

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

  }.freeze

  class << self
    def default_hash
      copy_deeply(DEFAULT, {})
    end

    def copy_deeply(source, dest)
      source.each do |key, value|
        case value
        when NilClass, TrueClass, FalseClass, Numeric, Symbol then
          dest[key] = value
        when Hash then
          dest[key] = copy_deeply(value, dest[key] || {})
        else
          dest[key] = value.dup
        end
      end
      dest
    end

    def [](obj)
      obj.is_a?(self) ? obj : new(obj)
    end
  end


end
