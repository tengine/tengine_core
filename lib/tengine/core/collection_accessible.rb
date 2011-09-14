require 'tengine/core'

module Tengine::Core::CollectionAccessible

  extend ActiveSupport::Concern

  module ClassMethods
    def array_text_accessor(attr_name, options = {})
      options = {:delimeter => ","}.update(options || {})
      delimeter = options[:delimeter]
      self.module_eval(<<-"EOS", __FILE__, __LINE__ + 1)
        def #{attr_name}_text
          #{attr_name} ? #{attr_name}.join(#{delimeter.inspect}) : ""
        end
        def #{attr_name}_text=(value)
          self.#{attr_name} = value.nil? ? [] :
            value.split(#{delimeter.inspect}).map(&:strip)
        end
      EOS
    end

    def map_yaml_accessor(attr_name)
      self.module_eval(<<-"EOS", __FILE__, __LINE__ + 1)
        def #{attr_name}_yaml
          YAML.dump({}.update(#{attr_name} || {}))
        end
        def #{attr_name}_yaml=(value)
          self.#{attr_name} = value.blank? ? nil : YAML.load(value)
        end
      EOS
    end
  end

end
