# -*- coding: utf-8 -*-
require 'tengine/core'

require 'active_support/dependencies'

module Tengine::Core::DslEvaluator
  attr_accessor :config

  def __evaluate__
    __setup_core_ext__
    begin
      Tengine.plugins.notify(self, :__evaluate__) do
        ActiveSupport::Dependencies.mechanism = config.tengined.cache_drivers ? :require : :load
        config.dsl_dir_path.tap do |dsl_dir_path|
          $LOAD_PATH.unshift(dsl_dir_path) unless $LOAD_PATH.include?(dsl_dir_path)
          ActiveSupport::Dependencies.autoload_paths = [dsl_dir_path]
        end
        config.dsl_file_paths.each do |f|
          Tengine::Core.stdout_logger.debug("now loading #{f}")
          # self.instance_eval(File.read(f), f)
          # require(f)
          config.tengined.cache_drivers ?
            load(f) :
            require_dependency( config.relative_path_from_dsl_dir(f) )
        end
      end
    ensure
      __teardown_core_ext__
    end
  end

  def __safety_event__(event)
    @__event__ = event
    begin
      yield if block_given?
    ensure
      @__event__ = nil
      @__event_wrapper__ = nil
    end
  end

  def __safety_driver__(driver)
    @__driver__ = driver
    @__session__ = driver.session
    begin
      yield if block_given?
    ensure
      @__driver__ = nil
      @__session__ = nil
    end
  end

  private

  def __setup_core_ext__
    Symbol.class_eval do
      def and(other)
        Tengine::Core::DslFilterDef.new(
          [self.to_s, other.to_s],
          {
            'method' => :and,
            'children' => [
              { 'pattern' => self, 'method' => :find_or_mark_in_session },
              { 'pattern' => other, 'method' => :find_or_mark_in_session },
            ]
          })
      end
      alias_method :&, :and

      def at(soruce_pattern)
        Tengine::Core::DslFilterDef.new(
          [self.to_s],
          {
            'method' => :match_source_name?,
            'pattern' => soruce_pattern.to_s,
          })
      end
    end
  end

  def __teardown_core_ext__
    Symbol.class_eval do
      remove_method(:&, :and)
    end
  end

  # requireではなく、ファイルを文字列としてロードしてinstance_evalで評価される場合、
  # Proc#source_locationが返す配列の一つ目の文字列がUTF-8ではなくASCII-8BITになってしまう。
  # そのままこれを使って検索すると、ヒットするべき検索もヒットしない。
  # これを回避するためにUTF-8として解釈するようにString#force_encodingを使用している。
  # http://doc.ruby-lang.org/ja/1.9.2/method/String/i/force_encoding.html
  def __source_location__(block)
    filepath, lineno = *block.source_location
    filepath = filepath.dup
    filepath.force_encoding(Encoding::UTF_8)
    return filepath, lineno
  end
end
