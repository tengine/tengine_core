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

class Tengine::Core::Config::Atd < Tengine::Support::Config::Definition::Suite
  # memoize については http://wota.jp/ac/?date=20081025#p11 などを参照してください
  extend ActiveSupport::Memoizable

  class << self
    # この辺は以前のTengine::Core::Configとの互換のために用意してあります
    def [](hash_or_suite)
      case hash_or_suite
      when Tengine::Core::Config::Atd then hash_or_suite
      when Hash then
        result = Tengine::Core::Config::Atd.new
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
    msg = e.message
    unless msg.include?(filepath)
      msg = "#{msg} in #{filepath}"
    end
    raise Tengine::Core::ConfigError, msg
  end


  def build
    banner <<EOS
Usage: tengine_atd [-k action] [-f path_to_config] [-D process_daemon]
         [-o mq_conn_host] [-p mq_conn_port] [-u mq_conn_user]
         [-s mq_conn_pass] [-e mq_exchange_name] [-q mq_queue_name]
         [-G heartbeat_atd_interval]
EOS

    field(:action, "start|stop", :type => :string, :default => "start")
    load_config(:config, "path/to/config_file", :type => :string)

    add(:process, Tengine::Core::Config::Atd::Process)
    field(:db, "settings to connect to db", :type => :hash, :default => {
        'host' => 'localhost',
        'port' => 27017,
        'username' => nil,
        'password' => nil,
        'database' => 'tengine_production',
      })

    group(:heartbeat) do
      add(:atd      , Tengine::Core::Config::Core::Heartbeat)
    end

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
    add(:application_log, Tengine::Core::Config::Atd::LoggerConfig,
      :parameters => {:logger_name => "application"},
      :dependencies => { :process_config => :process, :log_common => :log_common,}){
      self.formatter = lambda{|level, t, prog, msg| "#{t.iso8601} #{level} #{@process_identifier} #{msg}\n"}
    }
    add(:process_stdout_log, Tengine::Core::Config::Atd::LoggerConfig,
      :parameters => {:logger_name => "#{File.basename($PROGRAM_NAME)}_#{::Process.pid}_stdout"},
      :dependencies => { :process_config => :process, :log_common => :log_common,}){
      self.formatter = lambda{|level, t, prog, msg| "#{t.iso8601} STDOUT #{@process_identifier} #{msg}\n"}
    }
    add(:process_stderr_log, Tengine::Core::Config::Atd::LoggerConfig,
      :parameters => {:logger_name => "#{File.basename($PROGRAM_NAME)}_#{::Process.pid}_stderr"},
      :dependencies => { :process_config => :process, :log_common => :log_common,},
      :defaults => {
        :output => proc{ process_config.daemon ? "./log/#{logger_name}.log" : "STDERR" }}){
      self.formatter = lambda{|level, t, prog, msg| "#{t.iso8601} STDERR #{@process_identifier} #{msg}\n"}
    }

    separator("\nGeneral:")
    field(:verbose, "Show detail to this command", :type => :boolean)
    __action__(:version, "show version"){ STDOUT.puts Tengine::Core.version.to_s; exit }
    __action__(:dump_skelton, "dump skelton of config"){ STDOUT.puts YAML.dump(root.to_hash); exit }
    __action__(:help   , "show this help message"){ STDOUT.puts option_parser.help; exit }

    mapping({
        [:action] => :k,
        [:config] => :f,
        [:process, :daemon] => :D,

        [:event_queue, :connection, :host] => :o,
        [:event_queue, :connection, :port] => :p,
        [:event_queue, :connection, :user] => :u,
        [:event_queue, :connection, :pass] => :s,
        [:event_queue, :exchange  , :name] => :e,
        [:event_queue, :queue     , :name] => :q,

        [:heartbeat, :atd, :interval] => :G,

        [:verbose] => :V,
        [:version] => :v,
        [:help] => :h
      })
  end

  class Process
    include Tengine::Support::Config::Definition

    field :daemon, "process works on background.", :type => :boolean, :default => false
    field :pid_dir, "path/to/dir for PID created.", :type => :directory, :default => "./pids"
  end

  def heartbeat_period
    # [:][:heartbeat_period].to_i
    heartbeat.interval.to_i
  end

  def heartbeat_enabled?
    heartbeat_period > 0
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
    field :output, {
      :default => proc {
        process_config.daemon ? "./log/#{logger_name}.log" : "STDOUT"
      },
      :default_description => proc {
        "if daemon process then \"./log/#{logger_name}.log\" else \"STDOUT\""
      }
    }
    field :rotation, {
      :default => proc{ log_common.rotation },
      :default_description => proc{ "value of #{log_common.long_opt}-rotation" }
    }
    field :rotation_size, {
      :default => proc{ log_common.rotation_size },
      :default_description => proc{ "value of #{log_common.long_opt}-rotation-size" }
    }
    field :level, {
      :default => proc{ log_common.level },
      :default_description => proc{ "value of #{log_common.long_opt}-level" }
    }

    def new_logger *;
      super.tap {|i| i.formatter = self.formatter }
    end
  end

  def setup_loggers
    Tengine.logger = application_log.new_logger
    Tengine::Core.stdout_logger = process_stdout_log.new_logger
    Tengine::Core.stderr_logger = process_stderr_log.new_logger

    Tengine::Core.stdout_logger.info("#{self.class.name}#setup_loggers complete")
  rescue Exception
    Tengine::Core.stderr_logger.info("#{self.class.name}#setup_loggers failure")
    raise
  end

end
