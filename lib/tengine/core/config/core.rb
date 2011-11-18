# -*- coding: utf-8 -*-
require 'tengine/core/config'

module Tengine::Core::Config::Core
  def config
    @config ||= build_config
  end

  def build_config
    Tengine::Support::Config.suite do
      banner <<EOS
Usage: config_test [-k action] [-f path_to_config]
         [-H db_host] [-P db_port] [-U db_user] [-S db_pass] [-B db_database]

EOS

      field(:action, "test|load|start|enable|stop|force-stop|status|activate", :type => :string, :default => "start")
      load_config(:config, "path/to/config_file", :type => :string)

      add(:process, Tengine::Core::Config::Core::Process)
      add(:tengined, Tengine::Core::Config::Core::Tengined)
      field(:db, "settings to connect to db", :type => :hash)

      group(:event_queue, :hidden => true) do
        add(:connection, Tengine::Support::Config::Amqp::Connection)
        add(:exchange  , Tengine::Support::Config::Amqp::Exchange, :defaults => {:name => 'tengine_event_exchange'})
        add(:queue     , Tengine::Support::Config::Amqp::Queue   , :defaults => {:name => 'tengine_event_queue'})
      end

      add(:log_common, Tengine::Support::Config::Logger,
        :defaults => {
          :rotation      => 3          ,
          :rotation_size => 1024 * 1024,
          :level         => 'info'     ,
        })
      add(:application_log, App1::LoggerConfig,
        :logger_name => "application",
        :dependencies => { :process_config => :process, :log_common => :log_common,})
      add(:process_stdout_log, App1::LoggerConfig,
        :logger_name => "#{File.basename($PROGRAM_NAME)}_stdout",
        :dependencies => { :process_config => :process, :log_common => :log_common,})
      add(:process_stderr_log, App1::LoggerConfig,
        :logger_name => "#{File.basename($PROGRAM_NAME)}_stderr",
        :dependencies => { :process_config => :process, :log_common => :log_common,})

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
          [:process, :daemon] => :D,
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

  class Heartbeat
    include Tengine::Support::Config::Definition
    field :interval, "heartbeat interval seconds", :type => :integer, :default => 30
    field :expire  , "heartbeat expire seconds"  , :type => :integer, :default => 120
  end

end
