# -*- coding: utf-8 -*-
require 'tengine/core'

require 'tengine/event'
require 'tengine/mq'
require 'eventmachine'

class Tengine::Core::Bootstrap

  attr_accessor :config
  attr_writer :kernel

  def initialize(hash)
    @config = Tengine::Core::Config::Core[hash]
    prepare_trap
  end

  def prepare_trap; Signal.trap(:HUP) { kernel.stop } end

  DEBUG_CONFIG_ATTRS = [:dsl_dir_path, :dsl_file_paths, :dsl_version_path, :dsl_version].freeze

  def boot
    Tengine::Core.stdout_logger.debug(DEBUG_CONFIG_ATTRS.map{|attr| "#{attr}: " << config.send(attr).inspect}.join(", "))
    case config[:action]
    when "load" then load_dsl
    when "start" then
      load_dsl unless config[:tengined][:skip_load]
      start_kernel
    when "test" then test_connection
    when "enable" then enable_drivers
    else
      raise ArgumentError, "config[:action] in boot method must be test|load|start|enable but was #{config[:action]} "
    end
  end

  def load_dsl
    if dsl_version_document = Tengine::Core::Setting.first(:conditions => {:name => "dsl_version"})
      dsl_version_document.value = config.dsl_version
      dsl_version_document.save!
    else
      Tengine::Core::Setting.create!(:name => "dsl_version", :value => config.dsl_version)
    end
    Tengine.plugins.notify(self, :load_dsl) do
      context = kernel.dsl_context
      context.__evaluate__
    end
  end

  def kernel
    @kernel ||= Tengine::Core::Kernel.new(config)
  end

  def start_kernel(&block)
    Tengine.plugins.notify(self, :start_kernel) do
      kernel.start(&block)
    end
  end

  def stop_kernel
    Tengine.plugins.notify(self, :stop_kernel) do
      kernel.stop
    end
  end

  def enable_drivers
    drivers = Tengine::Core::Driver.where(:version => config.dsl_version, :enabled_on_activation => true)
    drivers.each{ |d| d.update_attribute(:enabled, true) }
  end

  def test_connection
    config[:tengined][:load_path] = File.expand_path("connection_test/fire_bar_on_foo.rb", File.dirname(__FILE__))
    config.prepare_dir_and_paths(true)

    begin
      load_dsl
      start_kernel do |mq| # このブロックは Tengine::Core::Kernel#activateのEM.runに渡されたブロックから呼び出されます。
        teardown = lambda do |result|
          EM.next_tick do
            Tengine::Core.stdout_logger.info(result)
            stop_kernel
          end
        end
        # http://keijinsonyaban.blogspot.com/2010/12/eventmachine.html のEM.defer(op, callback)を参照
        EM.defer(lambda{start_connection_test(mq)}, teardown)
      end
      Tengine::Core::stdout_logger.info("Connection test success.")
    rescue Exception => e
      Tengine::Core::stderr_logger.error("Connection test failure: [#{e.class.name}] #{e.message}")
    end
  end

  def start_connection_test(mq)
    require 'timeout'
    timeout(10) do
      connection_test_completed = false
      Tengine.callback_for_test = lambda do |event_type_name|
        case event_type_name
        when :foo then
          Tengine::Core.stdout_logger.info("handing :foo successfully.")
        when :bar then
          Tengine::Core.stdout_logger.info("handing :bar successfully.")
          connection_test_completed = true
        else
          Tengine::Core.stderr_logger.error("Unexpected event: #{event_type_name}")
        end
      end
      Tengine::Event.instance_variable_set(:@mq_suite, mq)
      Tengine::Event.fire(:foo, :level_key => :info, :keep_connection => true)
      loop do
        sleep(0.1)
        return if connection_test_completed
      end
    end
  end

  # 自動でログ出力する
  extend Tengine::Core::MethodTraceable
  method_trace(:prepare_trap, :boot, :load_dsl, :start_kernel, :stop_kernel,
    :enable_drivers, :test_connection, :start_connection_test)

end
