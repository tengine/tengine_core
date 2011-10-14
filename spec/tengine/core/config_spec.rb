# -*- coding: utf-8 -*-
require 'spec_helper'

require 'tengine/event'

describe Tengine::Core::Config do

  # log_configのテストは spec/models/tengine/core/config_spec/log_config_spec.rb にあります。

  describe :[] do
    it "should convert a Hash to a Tengine::Core::Config" do
      converted = Tengine::Core::Config[{ :tengined => { :daemon => true}}]
      converted.should be_a(Tengine::Core::Config)
      converted[:tengined][:daemon].should be_true
    end

    it "should return same Tengine::Core::Config" do
      converted = Tengine::Core::Config.new(:tengined => { :daemon => true})
      Tengine::Core::Config[converted].should == converted
    end
  end

  context "デフォルト" do
    subject do
      Tengine::Core::Config.new
    end
    its(:status_dir){ should == "./tmp/tengined_status" }
    its(:activation_dir){ should == "./tmp/tengined_activations" }

    its(:confirmation_threshold){ should == Tengine::Event::LEVELS_INV[:info] }
    its(:heartbeat_enabled?){ should == false }
  end


  shared_examples_for "ディレクトリもファイルも存在しない場合はエラー" do |path|
    before do
      @error_message = "file or directory doesn't exist. #{path}"
      Dir.should_receive(:exist?).with(path).and_return(false)
      File.should_receive(:exist?).with(path).and_return(false)
    end

    it :dsl_dir_path do
      expect{ subject.dsl_dir_path }.should raise_error(Tengine::Core::ConfigError, @error_message)
    end

    it :dsl_file_paths do
      expect{ subject.dsl_file_paths }.should raise_error(Tengine::Core::ConfigError, @error_message)
    end

    it :dsl_version_path do
      expect{ subject.dsl_version_path }.should raise_error(Tengine::Core::ConfigError, @error_message)
    end

    it :dsl_version do
      expect{ subject.dsl_version }.should raise_error(Tengine::Core::ConfigError, @error_message)
    end
  end

  context "load_pathに絶対パス" do

    shared_examples_for "絶対パス指定時のパスの振る舞い" do
      it :dsl_dir_path do
        subject.dsl_dir_path.should == "/var/lib/tengine"
      end

      it :dsl_version_path do
        subject.dsl_version_path.should == "/var/lib/tengine/VERSION"
      end

      it "VERSIONファイルがある場合" do
        File.should_receive(:exist?).with("/var/lib/tengine/VERSION").and_return(true)
        File.should_receive(:read).and_return("TEST20110905164100")
        subject.dsl_version.should == "TEST20110905164100"
      end

      it "VERSIONファイルがない場合" do
        File.should_receive(:exist?).with("/var/lib/tengine/VERSION").and_return(false)
        t = Time.local(2011,9,5,17,28,30)
        Time.stub!(:now).and_return(t)
        subject.dsl_version.should == "20110905172830"
      end
    end

    context "のディレクトリを指定する設定ファイル" do
      subject do
        Tengine::Core::Config.new(:config => File.expand_path("config_spec/config_with_dir_absolute_load_path.yml", File.dirname(__FILE__)))
      end
      it "should allow to read value by using []" do
        expected = {
          'daemon' => true,
          "activation_timeout" => 300,
          "load_path" => "/var/lib/tengine",
          "pid_dir" => "/var/run/tengined_pids",
          "status_dir" => "/var/run/tengined_status",
          "activation_dir" => "/var/run/tengined_activations",
          "heartbeat_period" => 600,
          "confirmation_threshold" => "warn",
        }
        subject[:tengined].should == expected
        subject['tengined'].should == expected
        subject[:tengined]['daemon'].should == true
        subject[:tengined][:daemon].should == true
        subject[:event_queue][:connection][:host].should == "localhost"
        subject['event_queue']['connection']['host'].should == "localhost"
        subject[:event_queue][:queue][:name].should == "tengine_event_queue2"
        subject['event_queue']['queue']['name'].should == "tengine_event_queue2"
      end
      its(:heartbeat_enabled?){ should == true }

      describe :relative_path_from_dsl_dir do
        it "絶対パスが指定されるとdsl_dir_pathからの相対パスを返します" do
          Dir.should_receive(:exist?).with("/var/lib/tengine").and_return(true)
          subject.relative_path_from_dsl_dir("/var/lib/tengine/foo/bar").should == "foo/bar"
        end

        it "相対パスが指定されると（計算のしようがないので）そのまま返します" do
          subject.relative_path_from_dsl_dir("lib/tengine/foo/bar").should == "lib/tengine/foo/bar"
        end
      end

      describe :confirmation_threshold do
        it "--tengined-confirmation-levelで設定した値を数値に変換する" do
          subject.confirmation_threshold.should == Tengine::Event::LEVELS_INV[:warn]
        end
      end

      context "ディレクトリが存在する場合" do
        before do
          Dir.should_receive(:exist?).with("/var/lib/tengine").and_return(true)
        end

        it :dsl_file_paths do
          Dir.should_receive(:glob).
            with("/var/lib/tengine/**/*.rb").
            and_return(["/var/lib/tengine/foo/bar.rb"])
          subject.dsl_file_paths.should == ["/var/lib/tengine/foo/bar.rb"]
        end

        # C0カバレッジを100%にするために追加しています
        it "dsl_dir_path and dsl_file_paths" do 
          Dir.should_receive(:glob).
            with("/var/lib/tengine/**/*.rb").
            and_return(["/var/lib/tengine/foo/bar.rb"])
          subject.dsl_dir_path.should == "/var/lib/tengine"
          subject.dsl_file_paths.should == ["/var/lib/tengine/foo/bar.rb"]
        end

        it_should_behave_like "絶対パス指定時のパスの振る舞い"
      end

      it_should_behave_like "ディレクトリもファイルも存在しない場合はエラー", "/var/lib/tengine"
    end

    context "のファイルを指定する設定ファイル" do
      subject do
        Tengine::Core::Config.new(:config => File.expand_path("config_spec/config_with_file_absolute_load_path.yml", File.dirname(__FILE__)))
      end
      it "should allow to read value by using []" do
        expected = {
          'daemon' => true,
          "activation_timeout" => 300,
          "load_path" => "/var/lib/tengine/init.rb",
          "pid_dir" => "/var/run/tengined_pids",
          "status_dir" => "/var/run/tengined_status",
          "activation_dir" => "/var/run/tengined_activations",
          "heartbeat_period" => 600,
          "confirmation_threshold" => "warn",
        }
        subject[:tengined].should == expected
        subject['tengined'].should == expected
        subject[:tengined]['load_path'].should == "/var/lib/tengine/init.rb"
        subject[:tengined][:load_path].should == "/var/lib/tengine/init.rb"
      end

      describe :relative_path_from_dsl_dir do
        it "絶対パスが指定されるとdsl_dir_pathからの相対パスを返します" do
          Dir.should_receive(:exist?).with("/var/lib/tengine/init.rb").and_return(false)
          File.should_receive(:exist?).with("/var/lib/tengine/init.rb").and_return(true)
          subject.relative_path_from_dsl_dir("/var/lib/tengine/foo/bar").should == "foo/bar"
        end

        it "相対パスが指定されると（計算のしようがないので）そのまま返します" do
          subject.relative_path_from_dsl_dir("lib/tengine/foo/bar").should == "lib/tengine/foo/bar"
        end
      end

      context "ファイルが存在する場合" do
        before do
          Dir.should_receive(:exist?).with("/var/lib/tengine/init.rb").and_return(false)
          File.should_receive(:exist?).with("/var/lib/tengine/init.rb").and_return(true)
        end

        it :dsl_file_paths do
          subject.dsl_file_paths.should == ["/var/lib/tengine/init.rb"]
        end

        it_should_behave_like "絶対パス指定時のパスの振る舞い"
      end

      it_should_behave_like "ディレクトリもファイルも存在しない場合はエラー", "/var/lib/tengine/init.rb"
    end
  end

  context "指定した設定ファイルが存在しない場合" do
    it "例外を生成します" do
      config_path = File.expand_path("config_spec/unexist_config.yml", File.dirname(__FILE__))
      expect{
        Tengine::Core::Config.new(:config => config_path)
      }.to raise_error(Tengine::Core::ConfigError, /Exception occurred when loading configuration file: #{config_path}./)
    end
  end

  describe :default_hash do
    subject do
      @source = Tengine::Core::Config::DEFAULT
      Tengine::Core::Config.default_hash
    end
    it "must be copied deeply" do
      YAML.dump(subject).should == YAML.dump(@source)
    end
    it "must be differenct object(s)" do
      subject.object_id.should_not == @source.object_id
      subject[:action].object_id.should_not == @source[:action].object_id
      subject[:tengined].object_id.should_not == @source[:tengined].object_id
      subject[:tengined][:pid_dir].object_id.should_not == @source[:tengined][:pid_dir].object_id
      subject[:event_queue].object_id.should_not == @source[:event_queue].object_id
      subject[:event_queue][:connection].object_id.should_not == @source[:event_queue][:connection].object_id
      subject[:event_queue][:connection][:host].object_id.should_not == @source[:event_queue][:connection][:host].object_id
      subject[:event_queue][:queue][:name].should_not == @source[:event_queue][:queue][:name].object_id
    end
  end

  context "[BUG] tengined起動時に-fオプションで設定ファイルを指定した際に、設定ファイルに記載したdb-portの設定が有効でない" do
    before do
      @config_path = File.expand_path("config_spec/another_port.yml", File.dirname(__FILE__))
    end

    shared_examples_for "正しく読み込む" do
      it "DBについて" do
        @config.should be_a(Tengine::Core::Config) if @config
        hash = @config || @hash
        hash[:db][:port].should == 21039
        hash[:db][:host].should == 'localhost'
        hash[:db][:username].should == nil
        hash[:db][:password].should == nil
        hash[:db][:database].should == "tengine_production"
      end
    end

    context "バグストーリーに添付された設定ファイルをロード" do
      # このテストは元々パスしてました
      before do
        @config = Tengine::Core::Config.new(:config => @config_path)
      end
      it_should_behave_like "正しく読み込む"
    end

    context "起動コマンドの引数を解釈したConfig" do
      before do
        @config = Tengine::Core::Config.parse(["-f", @config_path]) # bin/tenginedではARGVが渡されます
      end
      it_should_behave_like "正しく読み込む"
    end

    context "起動コマンドの引数を解釈したHash" do
      before do
        @hash = Tengine::Core::Config.parse_to_hash(["-f", @config_path]) # bin/tenginedではARGVが渡されます
      end
      it ":configを除いてスケルトンとほとんど同じ" do
        @hash[:config].should == @config_path
        @hash[:config] = nil
        @hash.should == Tengine::Core::Config.skelton_hash
      end
    end

    describe 'Tengine::Core::Config.copy_deeply' do
      context "Tengine::Core::Config#initialize内部での使用#1" do
        before do
          @hash = ActiveSupport::HashWithIndifferentAccess.new(Tengine::Core::Config.default_hash)
          original_hash = Tengine::Core::Config.parse_to_hash(["-f", @config_path]) # bin/tenginedではARGVが渡されます
          config_hash = YAML.load_file(@config_path)
          Tengine::Core::Config.copy_deeply(config_hash, @hash)
        end
        it_should_behave_like "正しく読み込む"
      end

      context "Tengine::Core::Config#initialize内部での使用#2" do
        before do
          @hash = ActiveSupport::HashWithIndifferentAccess.new(Tengine::Core::Config.default_hash)
          original_hash = Tengine::Core::Config.parse_to_hash(["-f", @config_path]) # bin/tenginedではARGVが渡されます
          config_hash = YAML.load_file(@config_path)
          Tengine::Core::Config.copy_deeply(config_hash, @hash)
          Tengine::Core::Config.copy_deeply(original_hash, @hash)
        end
        it_should_behave_like "正しく読み込む"
      end
    end

  end

end
