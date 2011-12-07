# -*- coding: utf-8 -*-
require 'tengine/core'

class Tengine::Core::Plugins
  attr_reader :modules

  def initialize
    @modules = []
  end

  def add(plugin_module)
    return if modules.include?(plugin_module)
    Tengine::Core.stdout_logger.info("#{self.class.name}#add(#{plugin_module.name})")
    modules << plugin_module
    enable_plugin(plugin_module)
    plugin_module
  end

  def notify(sender, msg)
    if block_given?
      notify(sender, :"before_#{msg}")
      yield
      notify(sender, :"after_#{msg}")
    else
      modules.each do |m|
        m.notify(sender, msg) if m.respond_to?(:notify)
      end
    end
  end


  # 自動でログ出力する
  extend Tengine::Core::MethodTraceable
  method_trace(:add)

  private
  def enable_plugin(plugin_module)
    if loader = find_sub_module(plugin_module, :DslLoader, :dsl_loader)
      # Tengine::Core::DslLoadingContext.send(:include, loader)
      Tengine::Core::Kernel.top.singleton_class.send(:include, loader)
    end
    if binder = find_sub_module(plugin_module, :DslBinder, :dsl_binder)
      # Tengine::Core::DslBindingContext.send(:include, binder)
      # Tengine::Core::Kernel.top.singleton_class.send(:include, binder)
    end
  end

  private
  def find_sub_module(plugin_module, const_name, method_name)
    plugin_module.const_defined?(const_name) ? plugin_module.const_get(const_name) :
      plugin_module.respond_to?(method_name) ? plugin_module.send(method_name) : nil
  end

end
