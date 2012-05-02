# -*- coding: utf-8 -*-
require 'spec_helper'
require 'amqp'
require 'eventmachine'
require 'tengine/mq'
require 'tengine/event'

describe "Tengine::Core::Bootstrap" do

  describe "bootメソッドでは" do
    context "config[:action] => load の場合" do
      it "load_dslがよばれること" do
        options = { :action => "load" }
        bootstrap = Tengine::Core::Bootstrap.new(options)
        bootstrap.should_receive(:load_dsl)
        bootstrap.boot
      end
    end

    context "config[:action] => start かつ skipオプションが設定されている場合" do
      it "load_dslはよばれず、start_kernelのみよばれること" do
        options = {
          :action => "start",
          :tengined => {
            :skip_load => true,
            :skip_enablement => true,
            :wait_activation => false
          }
        }
        bootstrap = Tengine::Core::Bootstrap.new(options)
        bootstrap.should_receive(:start_kernel)
        # skip_loadオプションを指定してもtengine_core-0.5系の再設計により無視するように変更しました。
        # bootstrap.should_not_receive(:load_dsl)
        bootstrap.should_receive(:load_dsl)
        bootstrap.boot
      end
    end

    context "config[:action] => enable の場合" do
      it "enable_driversがよばれること" do
        options = { :action => "enable" }
        bootstrap = Tengine::Core::Bootstrap.new(options)
        bootstrap.should_receive(:enable_drivers)
        bootstrap.boot
      end
    end

    context "config[:action] => startで、skipオプションの指定がない場合" do
      it "load_dslとstart_kernelがよばれること" do
        options = { :action => "start" }
        bootstrap = Tengine::Core::Bootstrap.new(options)
        bootstrap.should_receive(:load_dsl)
        bootstrap.should_receive(:start_kernel)
        bootstrap.boot
      end
    end

    context "config[:action] => test の場合" do
      it "load_dsl, start_kernel, start_connection_test, stop_kernelがよばれること" do
        bootstrap = Tengine::Core::Bootstrap.new(:action => "test")
        bootstrap.should_receive(:load_dsl)
        bootstrap.should_receive(:start_kernel)
        # #stop_kernel は、#start_kernel に渡されるブロックから呼び出されます
        # bootstrap.should_receive(:stop_kernel)
        Tengine::Core.stdout_logger.should_receive(:info).with("Connection test success.")
        bootstrap.boot
      end

      it "start_kernelに渡されたブロックを実行する" do
        bootstrap = Tengine::Core::Bootstrap.new(:action => "test")
        bootstrap.should_receive(:load_dsl)
        mock_mq = mock(:mq)
        bootstrap.should_receive(:start_kernel).and_yield(mock_mq)
        EM.should_receive(:defer).with(an_instance_of(Proc), an_instance_of(Proc))
        Tengine::Core.stdout_logger.should_receive(:info).with("Connection test success.")
        bootstrap.boot
      end

      it "start_kernelに失敗するとstdout_loggerに出力する" do
        bootstrap = Tengine::Core::Bootstrap.new(:action => "test")
        bootstrap.should_receive(:load_dsl)
        bootstrap.should_receive(:start_kernel).and_raise(IOError.new("Something wrong."))
        Tengine::Core.stderr_logger.should_receive(:error).with("Connection test failure: [IOError] Something wrong.")
        bootstrap.boot
      end
    end

    context "config[:action]に想定外の値が設定された場合" do
      it "ArgumentErrorをraiseする" do
        options = { :action => 1 }
        bootstrap = Tengine::Core::Bootstrap.new(options)
        expect {
          bootstrap.boot
        }.to raise_error(ArgumentError, /config[:action] must be test|load|start|enable|stop|force-stop but was/)
      end
    end
  end

  describe :prepare_trap do
    it "シグナルハンドラが定義される" do
      mock_kernel = mock(:kernel)
      Signal.should_receive(:trap).with(:HUP)
#      Signal.should_receive(:trap).with(:QUIT)
      bootstrap = Tengine::Core::Bootstrap.new({})
    end
  end

  describe :load_dsl do
    it "Tengine::Core::DslLoaderのevaluateがよばれる" do
      options = { :action => "load" }

      bootstrap = Tengine::Core::Bootstrap.new(options)
      mock_config = mock(:config)
      mock_config.should_receive(:dsl_version).and_return("test2011102623595999")
      bootstrap.should_receive(:config).twice.and_return(mock_config)
      bootstrap.kernel.context.tap do |context|
        context.should_receive(:__evaluate__)
      end
      bootstrap.load_dsl
    end

    context "拡張モジュールあり" do
      before(:all) do
        @ext_mod1 = Module.new{}
        @ext_mod1.instance_eval do
          def dsl_loader; self; end
        end
        Tengine.plugins.add(@ext_mod1)
      end

      it "拡張モジュールがextendされ、Tengine::Core::DslLoaderとのevaluateがよばれる" do
        options = { :action => "load" }
        bootstrap = Tengine::Core::Bootstrap.new(options)
        mock_config = mock(:config)
        mock_config.should_receive(:dsl_version).and_return("test2011102623595999")
        bootstrap.should_receive(:config).twice.and_return(mock_config)
        bootstrap.kernel.context.tap do |context|
          context.is_a?(@ext_mod1).should be_true
          context.should_receive(:__evaluate__)
        end
        bootstrap.load_dsl
      end

    end

    context "Tengine::Core::Settingとしてdsl_versionが保存される" do
      shared_examples_for "dsl_versionに値が設定される" do
        it do
          Tengine::Core::Driver.delete_all
          Tengine::Core::Session.delete_all
          config = Tengine::Core::Config::Core.new({
              :tengined => {
                :load_path => File.expand_path('../../../examples/uc08_if_both_a_and_b_occurs.rb', File.dirname(__FILE__)),
              },
            })
          @bootstrap = Tengine::Core::Bootstrap.new(config)
          @bootstrap.load_dsl
          dsl_version_document = Tengine::Core::Setting.first(:conditions => {:name => "dsl_version"})
          dsl_version_document.should_not be_nil
          dsl_version_document.value.should == "20110902213500" # examples/VERSION の中身
        end
      end

      context "Tengine::Core::Settingにname=dsl_versionのドキュメントが存在しない" do
        before do
          Tengine::Core::Setting.delete_all
        end
        it_should_behave_like "dsl_versionに値が設定される"
      end

      context "Tengine::Core::Settingにname=dsl_versionのドキュメントが存在する場合" do
        before do
          Tengine::Core::Setting.delete_all
          Tengine::Core::Setting.create!(:name => "dsl_version", :value => "fooo")
        end
        it_should_behave_like "dsl_versionに値が設定される"
      end


    end

  end

  describe :start_kernel do
    it "Tengine::Core::Kernel#start がよばれる" do
      options = { :action => "start" }
      bootstrap = Tengine::Core::Bootstrap.new(options)

      mock_config = mock(:config)
      bootstrap.should_receive(:config).and_return(mock_config)
      mock_kernel = mock(:kernel)
      Tengine::Core::Kernel.should_receive(:new).with(mock_config).and_return(mock_kernel)
      mock_kernel.should_receive(:start)
      bootstrap.start_kernel
    end

  end

  describe :enable_drivers do
    before do
      # capistranoのデフォルトのデプロイ先を想定しています
      # see "BACK TO CONFIGURATION" in https://github.com/capistrano/capistrano/wiki/2.x-From-The-Beginning
      # http://www.slideshare.net/T2J/capistrano-tips-tips
      Dir.stub!(:pwd).and_return("/u/apps/app1/current")
    end

    before do
      Tengine::Core::Driver.delete_all
      t = Time.utc(2011,9,5,17,28,30)
      Time.stub!(:now).and_return(t)
      @time_str = "20110905172830"
      @d1 = Tengine::Core::Driver.create!(:name=>"driver1", :version=>@time_str, :enabled=>false, :enabled_on_activation=>true)
      @d2 = Tengine::Core::Driver.create!(:name=>"driver2", :version=>@time_str, :enabled=>false, :enabled_on_activation=>true)
      @d3 = Tengine::Core::Driver.create!(:name=>"driver3", :version=>@time_str, :enabled=>false, :enabled_on_activation=>true)
    end

    it "enabled=true に更新される" do
      Dir.stub!(:exist?).with("/u/apps/app1/current/examples").and_return(true)
      File.stub!(:exist?).with("/u/apps/app1/current/examples/VERSION").and_return(false)
      options = {
        :action => "enable",
        :tengined => { :load_path => "examples" }
      }
      bootstrap = Tengine::Core::Bootstrap.new(options)
      bootstrap.config.dsl_version.should == @time_str
      bootstrap.boot

      Tengine::Core::Driver.where(:version => @time_str).each do |d|
        d.enabled.should be_true
      end
    end
  end

  describe :start_connection_test do
    before do
      class << Tengine
        attr_accessor :callback_for_test
      end
    end
    after do
      class << Tengine
        remove_method :callback_for_test, :callback_for_test=
      end
    end

    it "イベント:fooを発火して、テスト用のDSLが受信後にbarを発火、それを受け取るイベントハンドラから通知が来るまで待つ" do
      bootstrap = Tengine::Core::Bootstrap.new(:action => "test")
      mock_mq = mock(:mq)
      Tengine::Event.should_receive(:fire).with(:foo, :level_key => :info, :keep_connection => true)
      bootstrap.should_receive(:loop).and_yield
      bootstrap.start_connection_test(mock_mq)
      #
      Tengine::Core.stdout_logger.should_receive(:info).with("handing :foo successfully.")
      Tengine.callback_for_test.call(:foo)
      Tengine::Core.stdout_logger.should_receive(:info).with("handing :bar successfully.")
      Tengine.callback_for_test.call(:bar)
      Tengine::Core.stderr_logger.should_receive(:error).with("Unexpected event: baz")
      Tengine.callback_for_test.call(:baz)
    end
  end

  describe :stop_kernel do
    it "Tengine::Core::Kernel#stop がよばれること" do
      options = { :action => "stop" }
      bootstrap = Tengine::Core::Bootstrap.new(options)

      mock_config = mock(:config)
      bootstrap.should_receive(:config).and_return(mock_config)
      mock_kernel = mock(:kernel)
      Tengine::Core::Kernel.should_receive(:new).with(mock_config).and_return(mock_kernel)
      mock_kernel.should_receive(:start)
      bootstrap.start_kernel
      mock_kernel.should_receive(:stop)
      bootstrap.stop_kernel
    end
  end

end
