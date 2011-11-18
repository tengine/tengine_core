require 'tengine/core'

require 'selectable_attr'

module Tengine::Core::SelectableAttr
  extend ActiveSupport::Concern

  included do
    include ::SelectableAttr::Base

    class << self
      def selectable_attr_with_i18n_scope(attr_name, *args, &block)
        enum = selectable_attr_without_i18n_scope(attr_name, *args, &block)
        enum.i18n_scope('selectable_attrs', self.name.underscore, attr_name.to_s)
        enum
      end
      alias_method_chain :selectable_attr, :i18n_scope

      def multi_selectable_attr_with_i18n_scope(attr_name, *args, &block)
        enum = multi_selectable_attr_without_i18n_scope(attr_name, *args, &block)
        enum.i18n_scope('selectable_attrs', self.name.underscore, attr_name.to_s)
        enum
      end
      alias_method_chain :multi_selectable_attr, :i18n_scope
    end

  end

end
