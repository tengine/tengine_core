# -*- coding: utf-8 -*-
require 'tengine/core'

require 'tengine/event'
require 'tengine/mq'
require 'eventmachine'

class Tengine::Core::Bootstrap

  attr_accessor :config
  attr_accessor :kernel

  def initialize(hash)
    @config = Tengine::Core::Config[hash]
    prepare_trap
  end

  def prepare_trap; Signal.trap(:HUP) { kernel.stop } end

  def boot
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
    obj = Tengine::Core::DslDummyContext.new
    obj.extend(Tengine::Core::DslLoader)
    obj.config = config
    obj.__evaluate__
  end

  def start_kernel(&block)
    @kernel = Tengine::Core::Kernel.new(config)
    kernel.start(&block)
  end

  def stop_kernel
    kernel.stop
  end

  def enable_drivers
    drivers = Tengine::Core::Driver.where(:version => config.dsl_version, :enabled_on_activation => true)
    drivers.each{ |d| d.update_attribute(:enabled, true) }
  end

  def test_connection
    config[:tengined][:load_path] = File.expand_path("connection_test/fire_bar_on_foo.rb", File.dirname(__FILE__))

    # VERSIONファイルの生成とバージョンアップの書き込み
    version_file = File.open("#{config.dsl_dir_path}/VERSION", "w")
    version_file.write(Time.now.strftime("%Y%m%d%H%M%S").to_s)
    version_file.close

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
      Tengine::Event.fire(:foo, :level_key => :info)
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
