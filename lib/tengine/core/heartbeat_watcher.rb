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
require_relative 'config'
require_relative 'method_traceable'

class Tengine::Core::HeartbeatWatcher

  def initialize argv
    @uuid = UUID.new.generate
    @config = Tengine::Core::Config::Core.parse argv
    @pid = sprintf "process:%s/%d", ENV["MM_SERVER_NAME"], Process.pid
  end

  def sender
    @sender ||= Tengine::Event::Sender.new Tengine::Mq::Suite.new(@config[:event_queue])
  end

  def send_last_event
    sender.fire "finished.process.hbw.tengine", :key => @uuid, :source_name => @pid, :sender_name => @pid, :occurred_at => Time.now, :level_key => :info, :keep_connection => true
    sender.stop
  end

  def send_periodic_event
    sender.fire "hbw.heartbeat.tengine", :key => @uuid, :source_name => @pid, :sender_name => @pid, :occurred_at => Time.now, :level_key => :debug, :keep_connection => true, :retry_count => 0
  end

  def send_invalidate_event type, e0
    obj = e0.as_document.to_hash.inject({}) {|r, (k, v)| r.update(k.to_sym => v) }
    Tengine.logger.info "Heartbeat expiration detected! for #{e0.event_type_name} of #{e0.source_name}: last seen #{e0.occurred_at} (#{(Time.now - e0.occurred_at).to_f} secs before)"
    obj.delete :_id
    obj.delete :confirmed
    obj.delete :updated_at
    obj.delete :created_at
    obj[:event_type_name] = type
    obj[:level] = Tengine::Event::LEVELS_INV[:error]
    e1 = Tengine::Event.new obj
    sender.fire e1, :keep_connection => true
  end

  def search_for_invalid_heartbeat
    t = Time.now
    a = @config[:heartbeat].to_hash.each_pair.map do |e, h|
      Tengine::Core::Event.where(
                                 :event_type_name => "#{e}.heartbeat.tengine",
                                 :occurred_at.lte => t - h[:expire]
                                 )
    end
    a.flatten.each_next_tick do |i|
      yield i if i
    end
  end

  def shutdown
    EM.run do
      EM.cancel_timer @invalidate if @invalidate
      EM.cancel_timer @periodic if @periodic
      send_last_event
    end
  end

  def run __file__
    pdir = File.expand_path @config[:process][:pid_dir]
    fname = File.basename __file__
    cwd = Dir.getwd
    Daemons.run_proc fname, :ARGV => ['run'], :multiple => true, :ontop => !@config[:process][:daemon], :dir_mode => :normal, :dir => pdir do
      Dir.chdir cwd do
        @config.setup_loggers
        Tengine::Core::MethodTraceable.disabled = !@config[:verbose]
        Mongoid.config.from_hash @config[:db]
        Mongoid.config.option :persist_in_safe_mode, :default => true
        require 'amqp'
        Mongoid.logger = AMQP::Session.logger = Tengine.logger
        EM.run do
          sender.wait_for_connection do
            @invalidate = EM.add_periodic_timer 1 do # !!! MAGIC NUMBER
              search_for_invalid_heartbeat do |obj|
                type = case obj.event_type_name when /job|core|hbw/ then
                         "expired.#$&.heartbeat.tengine"
                       end
                EM.next_tick do
                  send_invalidate_event type, obj
                end
              end
            end
            int = @config[:heartbeat][:hbw][:interval].to_i
            if int and int > 0
              @periodic = EM.add_periodic_timer int do
                send_periodic_event
              end
            end
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
