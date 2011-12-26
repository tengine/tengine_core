# -*- coding: utf-8 -*-
require 'daemons'
require 'eventmachine'
require 'mongoid'
require 'uuid'

$LOAD_PATH.push File.expand_path("../../../../lib/", __FILE__)

require 'tengine/core'
require 'tengine/event'
require 'tengine/mq'

# explicit loading
require_relative 'config/atd'
require_relative 'method_traceable'
require_relative 'schedule'

class Tengine::Core::Scheduler

  def initialize argv
    @uuid = UUID.new.generate
    @config = Tengine::Core::Config::Atd.parse argv
    @daemonize_options = {
      :app_name => 'tengine_atd',
      :ARGV => [@config[:action]],
      :ontop => !@config[:process][:daemon],
      :multiple => true,
      :dir_mode => :normal,
      :dir => File.expand_path(@config[:process][:pid_dir]),
    }

    Tengine::Core::MethodTraceable.disabled = !@config[:verbose]
  rescue Exception
    puts "[#{$!.class.name}] #{$!.message}\n  " << $!.backtrace.join("\n  ")
    raise
  end

  def sender
    @sender ||= Tengine::Event::Sender.new Tengine::Mq::Suite.new(@config[:event_queue])
  end

  def pid
    @pid ||= sprintf "process:%s/%d", ENV["MM_SERVER_NAME"], Process.pid
  end

  def send_last_event
    sender.fire "finished.process.atd.tengine", :key => @uuid, :source_name => pid, :sender_name => pid, :occurred_at => Time.now, :level_key => :info, :keep_connection => true
    sender.stop
  end

  def send_periodic_event
    sender.fire "atd.heartbeat.tengine", :key => @uuid, :source_name => pid, :sender_name => pid, :occurred_at => Time.now, :level_key => :debug, :keep_connection => true, :retry_count => 0
  end

  def send_scheduled_event sched
    Tengine.logger.info "Scheduled time (#{sched.scheduled_at}) has come.  Now firing #{sched.event_type_name} for #{sched.source_name}"
    sender.fire sched.event_type_name, :source_name => sched.source_name, :sender_name => pid, :occurred_at => Time.now, :level_key => :info, :keep_connection => true, :properties => sched.properties
  end

  def mark_schedule_done sched
    # 複数のマシンで複数のatdが複数動いている可能性があり、その場合には複数の
    # atdが同時に同じエントリに更新をかける可能性はとても高い。そのような状況
    # でもエラーになってはいけない。
    Tengine::Core::Schedule.where(
      :_id => sched.id,
      :status => Tengine::Core::Schedule::SCHEDULED
    ).update_all(
      :status => Tengine::Core::Schedule::FIRED
    )
  end

  def search_for_schedule
    Tengine::Core::Schedule.where(
      :scheduled_at.lte => Time.now,
      :status => Tengine::Core::Schedule::SCHEDULED
    ).each_next_tick do |i|
      yield i
    end
  end

  def run(__file__)
    case @config[:action].to_sym
    when :start
      start_daemon(__file__)
    when :stop
      stop_daemon(__file__)
    when :restart
      stop_daemon(__file__)
      start_daemon(__file__)
    end
  end

  def start_daemon(__file__)
    pdir = File.expand_path @config[:process][:pid_dir]
    fname = File.basename __file__
    cwd = Dir.getwd
    #    Daemons.run_proc(fname, :ARGV => [@config[:action]], :multiple => true, :ontop => !@config[:process][:daemon], :dir_mode => :normal, :dir => pdir) do
    Daemons.run_proc(fname, @daemonize_options) do
      Dir.chdir(cwd) { self.start }
    end
  end

  def stop_daemon(__file__)
    fname = File.basename __file__
    Daemons.run_proc(fname, @daemonize_options)
  end

  def shutdown
    EM.run do
      EM.cancel_timer @periodic if @periodic
      send_last_event
    end
  end

  def start
    @config.setup_loggers

    Mongoid.config.from_hash @config[:db]
    Mongoid.config.option :persist_in_safe_mode, :default => true

    require 'amqp'
    Mongoid.logger = AMQP::Session.logger = Tengine.logger

    EM.run do
      sender.wait_for_connection do
        @invalidate = EM.add_periodic_timer 1 do # !!! MAGIC NUMBER
          search_for_schedule do |sched|
            send_scheduled_event sched
            mark_schedule_done sched
          end
        end
        int = @config[:heartbeat][:atd][:interval].to_i
        if int and int > 0
          @periodic = EM.add_periodic_timer int do
            send_periodic_event
          end
        end
      end
    end
  end

  extend Tengine::Core::MethodTraceable
  method_trace(*instance_methods(false))
end

# 
# Local Variables:
# mode: ruby
# coding: utf-8-unix
# indent-tabs-mode: nil
# tab-width: 4
# ruby-indent-level: 2
# fill-column: 79
# default-justification: full
# End:
