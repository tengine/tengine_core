# -*- coding: utf-8 -*-
require 'tengine/core/config'

require 'yaml'
require 'optparse'
require 'active_support/memoizable'

require 'tengine/support/yaml_with_erb'

Tengine::Support::Config::Definition::Group.module_eval do
  def symbolize_keys
    to_hash
  end
end

class Tengine::Core::Config::Core < Tengine::Support::Config::Definition::Suite
  # memoize については http://wota.jp/ac/?date=20081025#p11 などを参照してください
  extend ActiveSupport::Memoizable

  class << self
    # この辺は以前のTengine::Core::Configとの互換のために用意してあります
    def [](hash_or_suite)
      case hash_or_suite
      when Tengine::Core::Config::Core then hash_or_suite
      when Hash then
        result = Tengine::Core::Config::Core.new
        result.load(hash_or_suite)
        result
      else
        raise "unsupported class: #{hash_or_suite.class.inspect}"
      end
    end

    def default_hash
      new.to_hash
    end
    alias_method :skelton_hash, :default_hash

    def parse_to_hash(args)
      config = new
      config.parse!(args)
      result = new
      result.config = config.config
      result.to_hash
    end

    def parse(args)
      config = new
      config.parse!(args)
      config
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

  end

  def initialize(hash_or_filepath = nil)
    build if respond_to?(:build)
    case hash_or_filepath
    when Hash then
      if config = hash_or_filepath[:config]
        load_file(config)
      else
        load(hash_or_filepath)
      end
    when String then load_file(hash_or_filepath)
    end
  end

  def load_file(filepath)
    super
  rescue Exception => e
    raise Tengine::Core::ConfigError, "Exception occurred when loading configuration file: #{filepath}."
  end


  def build
    banner <<EOS
Usage: tengined [-k action] [-f path_to_config] [-T path/to/file_or_dir]
         [-o mq_conn_host] [-p mq_conn_port] [-u mq_conn_user]
         [-s mq_conn_pass] [-e mq_exchange_name] [-q mq_queue_name]
EOS

    field(:action, "test|load|start|enable|stop|force-stop|status|activate", :type => :string, :default => "start")
    load_config(:config, "path/to/config_file", :type => :string)

    add(:process, Tengine::Core::Config::Core::Process)
    add(:tengined, Tengine::Core::Config::Core::Tengined)
    field(:db, "settings to connect to db", :type => :hash, :default => {
        'host' => 'localhost',
        'port' => 27017,
        'username' => nil,
        'password' => nil,
        'database' => 'tengine_production',
      })

    group(:event_queue, :hidden => true) do
      add(:connection, AmqpConnection)
      add(:exchange  , Tengine::Support::Config::Amqp::Exchange, :defaults => {:name => 'tengine_event_exchange'})
      add(:queue     , Tengine::Support::Config::Amqp::Queue   , :defaults => {:name => 'tengine_event_queue'})
    end

    add(:log_common, Tengine::Support::Config::Logger,
      :defaults => {
        :rotation      => 3          ,
        :rotation_size => 1024 * 1024,
        :level         => 'info'     ,
      })
    add(:application_log, Tengine::Core::Config::Core::LoggerConfig,
      :parameters => {:logger_name => "application"},
      :dependencies => { :process_config => :process, :log_common => :log_common,})
    add(:process_stdout_log, Tengine::Core::Config::Core::LoggerConfig,
      :parameters => {:logger_name => "#{File.basename($PROGRAM_NAME)}_stdout"},
      :dependencies => { :process_config => :process, :log_common => :log_common,})
    add(:process_stderr_log, Tengine::Core::Config::Core::LoggerConfig,
      :parameters => {:logger_name => "#{File.basename($PROGRAM_NAME)}_stderr"},
      :dependencies => { :process_config => :process, :log_common => :log_common,},
      :defaults => {
        :output => proc{ process_config.daemon ? "./log/#{logger_name}.log" : "STDERR" }})

    group(:heartbeat, :hidden => true) do
      add(:core     , Tengine::Core::Config::Core::Heartbeat)
      add(:job      , Tengine::Core::Config::Core::Heartbeat, :defaults => {:interval => 5, :expire => 20})
      add(:hbw      , Tengine::Core::Config::Core::Heartbeat)
      add(:resourcew, Tengine::Core::Config::Core::Heartbeat)
      add(:atd      , Tengine::Core::Config::Core::Heartbeat)
    end

    separator("\nGeneral:")
    field(:verbose, "Show detail to this command", :type => :boolean)
    __action__(:version, "show version"){ STDOUT.puts Tengine::Core.version.to_s; exit }
    __action__(:dump_skelton, "dump skelton of config"){ STDOUT.puts YAML.dump(root.to_hash); exit }
    __action__(:help   , "show this help message"){ STDOUT.puts option_parser.help; exit }

    mapping({
        [:action] => :k,
        [:config] => :f,
        [:tengined, :daemon] => :D,
        [:tengined, :load_path] => :T,
        [:tengined, :heartbeat_period] => :G,
        [:tengined, :confirmation_threshold] => :C,

        [:event_queue, :connection, :host] => :o,
        [:event_queue, :connection, :port] => :p,
        [:event_queue, :connection, :user] => :u,
        [:event_queue, :connection, :pass] => :s,
        [:event_queue, :exchange  , :name] => :e,
        [:event_queue, :queue     , :name] => :q,

        [:verbose] => :V,
        [:version] => :v,
        [:help] => :h
      })
  end

  class Process
    include Tengine::Support::Config::Definition

    field :daemon, "process works on background.", :type => :boolean, :default => false
    field :pid_dir, "path/to/dir for PID created.", :type => :directory, :default => "./tmp/tengined_pids"
  end

  class Tengined
    include Tengine::Support::Config::Definition

    field :load_path             , "[REQUIRED] path/to/file_or_dir. ignored with \"-k test\".", :type => :string
    field :skip_load             , "doesn't load event handler when start. usually use with --daemon option. [only for command]", :type => :boolean
    field :skip_enablement       , "doesn't enable event handler when start. usually use with --daemon option. [only for command]", :type => :boolean
    field :wait_activation       , "wait activation when start. usually use with --daemon option [only for command]", :type => :boolean
    field :activation_timeout    , "period to wait for making activation file.", :type => :integer, :default => 300
    field :status_dir            , "path/to/dir.", :type => :directory, :default => "./tmp/tengined_status"
    field :activation_dir        , "path/to/dir.", :type => :directory, :default => "./tmp/tengined_activations"
    field :heartbeat_period      , "the second of period which heartbeat event be fired. disable heartbeat if 0.", :type => :integer, :default => 0
    field :confirmation_threshold, "the event which is this level or less will be made confirmed automatically. debug/info/warn/error/fatal. ", :type => :string, :default => 'info'
  end

  class AmqpConnection < Tengine::Support::Config::Amqp::Connection
    field :vhost, :default => '/'
    field :user , :default => 'guest'
    field :pass , :default => 'guest'
    field :logging, :type => :boolean, :default => false
    field :insist, :type => :boolean, :default => false
    field :auto_reconnect_delay, :type => :integer, :default => 1
  end

  class LoggerConfig < Tengine::Support::Config::Logger
    parameter :logger_name
    depends :process_config
    depends :log_common
    field :output,
      :default => proc{
        process_config.daemon ?
        "./log/#{logger_name}.log" : "STDOUT" },
      :default_description => proc{"if daemon process then \"./log/#{logger_name}.log\" else \"STDOUT\""}
    field :rotation,
      :default => proc{ log_common.rotation },
      :default_description => proc{"value of #{log_common.long_opt}-rotation"}
    field :rotation_size,
      :default => proc{ log_common.rotation_size },
      :default_description => proc{"value of #{log_common.long_opt}-rotation-size"}
    field :level,
      :default => proc{ log_common.level },
      :default_description => proc{"value of #{log_common.long_opt}-level"}
  end

  class Heartbeat
    include Tengine::Support::Config::Definition
    field :interval, "heartbeat interval seconds", :type => :integer, :default => 30
    field :expire  , "heartbeat expire seconds"  , :type => :integer, :default => 120
  end

  def dsl_load_path
    original = self[:tengined][:load_path]
    # 本来は指定する必要はありませんが、specでDir.pwdをstubで返すようにするために、明示的に第２引数にDir.pwdを指定しています
    original ? File.expand_path(original, Dir.pwd) : nil
  end
  memoize :dsl_load_path

  def prepare_dir_and_paths(force = false)
    return if !force && @prepare_dir_and_paths_done
    path = dsl_load_path(true) # キャッシュをクリア
    if path.nil?
      @dsl_dir_path = nil
      @dsl_file_paths = []
    elsif Dir.exist?(path)
      @dsl_dir_path = File.expand_path(path)
      @dsl_file_paths = Dir.glob("#{@dsl_dir_path}/**/*.rb")
    elsif File.exist?(path)
      @dsl_dir_path = File.expand_path(File.dirname(path))
      @dsl_dir_path.force_encoding(@dsl_dir_path.encoding)
      @dsl_file_paths = [dsl_load_path]
    else
      raise Tengine::Core::ConfigError, "file or directory doesn't exist. #{path}"
    end
    @prepare_dir_and_paths_done = true
  end

  def dsl_dir_path
    prepare_dir_and_paths
    @dsl_dir_path
  end

  def dsl_file_paths
    prepare_dir_and_paths
    @dsl_file_paths
  end

  def dsl_version_path
    path = dsl_dir_path
    path ? File.expand_path("VERSION", path) : nil
  end
  memoize :dsl_version_path

  def dsl_version
    path = dsl_version_path
    (path && File.exist?(dsl_version_path)) ? File.read(dsl_version_path).strip : Time.now.strftime("%Y%m%d%H%M%S")
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

end
