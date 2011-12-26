# -*- coding: utf-8 -*-
require 'tengine/core'

require 'active_support/core_ext/array/extract_options'

module Tengine::Core::OptimisticLock
  extend ActiveSupport::Concern

  included do
    cattr_accessor :lock_optimistically, :instance_writer => false
    self.lock_optimistically = true

    class << self
      alias_method :locking_field=, :set_locking_field
    end
  end

  class RetryOverError < StandardError
  end

  def update_with_lock(options = {})
    retry_count = options[:retry] || 5
    idx = 1
    while idx <= retry_count
      yield
      return if __find_and_modify__
      reload
      idx += 1
    end
    raise RetryOverError, "retried #{retry_count} times but failed to update"
  end

  def __find_and_modify__
    lock_field_name = self.class.locking_field
    current_version = self.send(lock_field_name)
    hash = as_document.dup
    new_version = current_version + 1
    hash[lock_field_name] = new_version
    result = self.class.collection.find_and_modify({
        :query => {:_id => self.id, lock_field_name.to_sym => current_version},
        :update => hash
      })
    send("#{lock_field_name}=", new_version)
    result
  end

  # ActiveRecord::Locking::Optimistic::ClassMethods を参考に実装しています
  # https://github.com/rails/rails/blob/master/activerecord/lib/active_record/locking/optimistic.rb
  module ClassMethods
    DEFAULT_LOCKING_FIELD = 'lock_version'.freeze

    # Set the field to use for optimistic locking. Defaults to +lock_version+.
    def set_locking_field(value = nil, &block)
      define_attr_method :locking_field, value, &block
      value
    end

    # The version field used for optimistic locking. Defaults to +lock_version+.
    def locking_field
      reset_locking_field
    end

    # Reset the field used for optimistic locking back to the +lock_version+ default.
    def reset_locking_field
      set_locking_field DEFAULT_LOCKING_FIELD
    end
  end

end
