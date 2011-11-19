# -*- coding: utf-8 -*-
require 'spec_helper'

describe Tengine::Core::Config::Core do

  context "ログの設定なし" do
    {
      true => "デーモン起動",
      false => "非デーモン起動",
    }.each do |daemon_process, context_name|
      context(context_name) do
        before{ @config = Tengine::Core::Config::Core.new(:process => {:daemon => daemon_process})}

        context "正しい設定の場合" do

          context :application_log do
            it do
              @config[:process][:daemon].should == daemon_process

              mock_logger = mock(:logger)
              Logger.should_receive(:new).
                with(daemon_process ? "./log/application.log" : STDOUT, 3, 1024 * 1024).
                and_return(mock_logger)
              mock_logger.should_receive(:level=).with(Logger::INFO)
              @config.application_log.new_logger
            end
          end

          context :process_stdout_log do
            it do
              mock_logger = mock(:logger)
              Logger.should_receive(:new).
                with(daemon_process ? %r{^\./log/.*_stdout\.log} : STDOUT, 3, 1024 * 1024).
                and_return(mock_logger)
              mock_logger.should_receive(:level=).with(Logger::INFO)
              @config.process_stdout_log.new_logger
            end
          end

          context :process_stderr_log do
            it do
              mock_logger = mock(:logger)
              Logger.should_receive(:new).
                with(daemon_process ? %r{^\./log/.*_stderr\.log} : STDERR, 3, 1024 * 1024).
                and_return(mock_logger)
              mock_logger.should_receive(:level=).with(Logger::INFO)
              @config.process_stderr_log.new_logger
            end
          end
        end

        context :invalid_log_type_name do
          it "should raise ArgumentError"do
            expect{
              @config.invalid_log_type_name
            }.to raise_error(NoMethodError)
          end
        end


      end
    end
  end

  context "共通設定なし各ログの設定あり" do
    {
      true => "デーモン起動の場合",
      false => "非デーモン起動の場合",
    }.each do |daemon_process, context_name|
      context(context_name) do
        before do
          @config = Tengine::Core::Config::Core.new({
              :process => {:daemon => daemon_process},
              :application_log => {
                :output        => "/var/log/tengined/application.log",
                :rotation      => "daily",
                :level         => "error",
              },
              :process_stdout_log => {
                :output        => "/var/log/tengined/process_stdout.log",
                :rotation      => "weekly",
                :level         => "info",
              },
              :process_stderr_log => {
                :output        => "/var/log/tengined/process_stderr.log",
                :rotation      => "monthly",
                :level         => "info",
              },
            })
        end

        context :application_log do
          it do
            mock_logger = mock(:logger)
            Logger.should_receive(:new).
              with("/var/log/tengined/application.log", "daily", 1048576).
              and_return(mock_logger)
            mock_logger.should_receive(:level=).with(Logger::ERROR)
            @config.application_log.new_logger
          end
        end

        context :process_stdout_log do
          it do
            mock_logger = mock(:logger)
            Logger.should_receive(:new).
              with("/var/log/tengined/process_stdout.log", "weekly", 1048576).
              and_return(mock_logger)
            mock_logger.should_receive(:level=).with(Logger::INFO)
            @config.process_stdout_log.new_logger
          end
        end

        context :process_stderr_log do
          it do
            mock_logger = mock(:logger)
            Logger.should_receive(:new).
              with("/var/log/tengined/process_stderr.log", "monthly", 1048576).
              and_return(mock_logger)
            mock_logger.should_receive(:level=).with(Logger::INFO)
            @config.process_stderr_log.new_logger
          end
        end

      end
    end
  end

  context "共通設定あり各ログの設定あり" do
    {
      true => "デーモン起動の場合",
      false => "非デーモン起動の場合",
    }.each do |daemon_process, context_name|
      context(context_name) do
        before do
          @config = Tengine::Core::Config::Core.new({
              :process => {:daemon => daemon_process},
              :log_common => {
                :rotation      => "daily",
                :level         => "info",
              },
              :application_log => {
                :output        => "/var/log/tengined/application.log",
              },
              :process_stdout_log => {
                :output        => "/var/log/tengined/process_stdout.log",
              },
              :process_stderr_log => {
                :output        => "/var/log/tengined/process_stderr.log",
                :rotation      => "monthly",
              },
            })
        end

        context :application_log do
          it do
            mock_logger = mock(:logger)
            Logger.should_receive(:new).
              with("/var/log/tengined/application.log", "daily", 1048576).
              and_return(mock_logger)
            mock_logger.should_receive(:level=).with(Logger::INFO)
            @config.application_log.new_logger
          end
        end

        context :process_stdout_log do
          it do
            mock_logger = mock(:logger)
            Logger.should_receive(:new).
              with("/var/log/tengined/process_stdout.log", "daily", 1048576).
              and_return(mock_logger)
            mock_logger.should_receive(:level=).with(Logger::INFO)
            @config.process_stdout_log.new_logger
          end
        end

        context :process_stderr_log do
          it do
            mock_logger = mock(:logger)
            Logger.should_receive(:new).
              with("/var/log/tengined/process_stderr.log", "monthly", 1048576).
              and_return(mock_logger)
            mock_logger.should_receive(:level=).with(Logger::INFO)
            @config.process_stderr_log.new_logger
          end
        end

      end
    end
  end


end
