# -*- coding: utf-8 -*-
require 'tengine/core/config'

require 'optparse'

class Tengine::Core::Config::Parser
  def initialize(default_hash, args)
    @hash = default_hash
    @args = args
    @option_parser = OptionParser.new
    setup
  end

  def option_parser
    @option_parser
  end
  alias_method :o, :option_parser

  def parse
    @option_parser.parse!(@args)
    @hash
  end

  def setup
  o.banner = <<EOS
Usage: tengined [-k action] [-f path_to_config] [-T path/to/file_or_dir]
         [-H db_host] [-P db_port] [-U db_user] [-S db_pass] [-B db_database]
         [-h mq_conn_host] [-p mq_conn_port] [-u mq_conn_user] [-s mq_conn_pass]
         [-v mq_conn_vhost] [-e mq_exchange_name] [-q mq_queue_name]
EOS

  o.separator ""
  o.separator "Basic:"
  o.on("-k", "--action=test|load|start|enable|stop|force-stop|status|activate", "default: start"){|v| @hash[:action] = v}
  o.on("-f", "--config=filepath"                , "Specify configuration file path."){|v| @hash[:config] = v}

  o.separator ""
  o.separator "Process:"
  {
    :load_path => ["-T", "[REQUIRED] path/to/file_or_dir. ignored with \"-k test\".", :hide_default => true],
    :daemon => ["-D", "ignored with \"-k test, -k load, -k enable\".", :hide_value => true],
    :skip_load => ["doesn't load event handler when start. usually use with --daemon option. [only for command]", :hide_value => true],
    :skip_enablement => ["doesn't enable event handler when start. usually use with --daemon option. [only for command]", :hide_value => true],
    :wait_activation => ["wait activation when start. usually use with --daemon option [only for command]", :hide_value => true],
    :activation_timeout => "period to wait for making activation file.",
    :pid_dir  => "path/to/dir.",
    :status_dir => "path/to/dir.",
    :activation_dir => "path/to/dir.",
    :heartbeat_period => ["-G", "the second of period which heartbeat event be fired. disable heartbeat if 0."],
    :confirmation_threshold => ["-C", "the event which is this level or less will be made confirmed automatically. debug/info/warn/error/fatal. "]
  }.each{|key, args| tengine_opt(:tengined, key, args)}

  o.separator ""
  o.separator "DB Connection:"
  {
    :host     => ["-O", "hostname to connect db."],
    :port     => ["-P", "port to connect db."],
    :username => ["-U", "username to connect db."],
    :password => ["-S", "password to connect db."],
    :database => ["-B", "database name to connect db."],
  }.each{|key, args| tengine_opt(:db, key, args)}

  o.separator ""
  o.separator "MQ subscription:"
  {
    :host  => ["-o", "hostname to connect queue server."],
    :port  => ["-p", "port to connect queue server."],
    :vhost => [      "vhost to connect queue server."],
    :user  => ["-u", "username to connect queue server."],
    :pass  => ["-s", "password to connect queue server."],
  }.each{|key, args| tengine_opt([:event_queue, :connection], key, args)}


  {
    :name    => ["-e", "exchange name to access to queue."],
    :type    => [     "exchange type to access to queue."],
    :durable => [     "exchange durable to access to queue"],
  }.each{|key, args| tengine_opt([:event_queue, :exchange], key, args)}

  {
    :name    => ["-q", "queue name to subscribe."],
    :durable => [     "queue durable to subscribe."],
  }.each{|key, args| tengine_opt([:event_queue, :queue], key, args)}

  o.separator ""
  o.separator "Log common options:"
  {
    :output        => ['file path or "STDOUT" / "STDERR"', :hide_value => true],
    :rotation      => ['rotation file count or daily,weekly,monthly.'],
    :rotation_size => ['number of max log file size.'],
    :level         => ['debug/info/warn/error/fatal.'],
  }.each{|key, args| tengine_opt(:log_common, key, args)}

  o.separator ""
  o.separator "Application log options:"
  {
    :output        => ['file path or "STDOUT" / "STDERR". default: if daemon process then “./log/application.log" else "STDOUT"', :hide_default => true],
    :rotation      => ['rotation file count or daily,weekly,monthly. default: value of --log-common-rotation', :hide_default => true],
    :rotation_size => ['number of max log file size. default: value of --log-common-rotation-size', :hide_default => true],
    :level         => ['debug/info/warn/error/fatal. default: value of --log-common-level', :hide_default => true],
  }.each{|key, args| tengine_opt(:application_log, key, args)}

  o.separator ""
  o.separator "Process STDOUT log options:"
  {
    :output        => ['file path or "STDOUT" / "STDERR". default: if daemon process then “./log/#{$PROGRAM_NAME}_#{Process.pid}_stdout.log" else "STDOUT"', :hide_default => true],
    :rotation      => ['rotation file count or daily,weekly,monthly. default: value of --log-common-rotation', :hide_default => true],
    :rotation_size => ['number of max log file size. default: value of --log-common-rotation-size', :hide_default => true],
    :level         => ['debug/info/warn/error/fatal. default: value of --log-common-level', :hide_default => true],
  }.each{|key, args| tengine_opt(:process_stdout_log, key, args)}

  o.separator ""
  o.separator "Process STDERR log options:"
  {
    :output        => ['file path or "STDOUT" / "STDERR". default: if daemon process then “./log/#{$PROGRAM_NAME}_#{Process.pid}_stderr.log" else "STDERR"', :hide_default => true],
    :rotation      => ['rotation file count or daily,weekly,monthly. default: value of --log-common-rotation', :hide_default => true],
    :rotation_size => ['number of max log file size. default: value of --log-common-rotation-size', :hide_default => true],
    :level         => ['debug/info/warn/error/fatal. default: value of --log-common-level', :hide_default => true],
  }.each{|key, args| tengine_opt(:process_stderr_log, key, args)}

  o.separator ""
  o.separator "General options:"
  o.on("-V", '--verbose', "Show detail to this command"){ @hash[:verbose] = true}
  o.on("-v", '--version', "Show version."){
    puts Tengine::Core.version.to_s
    exit;
  }
  o.on("-h", '--help', "Show this help message."){ puts o; exit}
  end

  private

  def tengine_opt(prefixes, base_name, args)
    prefixes = Array(prefixes)
    args = Array(args)
    options = args.last.is_a?(Hash) ? args.pop : {}
    description = args.pop
    short_arg = args.first
    long_arg = "--#{prefixes.join('-')}-#{base_name}".gsub(/_/, '-')
    datasource = prefixes.inject(@hash){|d, prefix| d[prefix]}
    if options[:hide_value]
      block = lambda{|v| datasource[base_name] = true}
    elsif options[:hide_default]
      long_arg << "=VAL"
      block = lambda{|v| datasource[base_name] = v}
    else
      long_arg << "=VAL"
      default_value = datasource[base_name]
      description << " default: #{default_value.inspect}"
      block = lambda{|v| datasource[base_name] = v}
    end
    on_args = [short_arg, long_arg, description].compact
    o.on(*on_args, &block)
  end


end
