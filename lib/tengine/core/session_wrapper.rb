# -*- coding: utf-8 -*-
require 'tengine/core'

require 'active_support/core_ext/array/extract_options'
require 'active_support/hash_with_indifferent_access'

class Tengine::Core::SessionWrapper

  def initialize(source, options = {})
    @options = options || {}
    @source = source
  end

  def system_properties
    @source.system_properties
  end

  def [](key)
    @source.properties[key.to_s]
  end

  def update(*args, &block)
    return if @options[:ignore_update]
    __update__(:properties, *args, &block)
  end

  def system_update(*args, &block)
    __update__(:system_properties, *args, &block)
  end

  private
  def __update__(target_name, *args, &block)
    if block_given?
      options = args.extract_options!
      retry_count = options[:retry] || 5
      idx = 1
      while idx <= retry_count
        values = ActiveSupport::HashWithIndifferentAccess.new(__get_properties__(target_name, idx > 0))
        yield(values)
        return if __find_and_modify__(target_name, values)
        idx += 1
      end
      raise Tengine::Core::OptimisticLock::RetryOverError, "retried #{retry_count} times but failed to update"
    else
      properties = args.first
      new_vals = __get_properties__(target_name).merge(properties.stringify_keys)
      @source.send("#{target_name}=", new_vals)
      @source.save!
    end
  end

  # テストで同時に値を取得したことを再現するために、
  # データを取得するメソッドで待ち合わせするフックとなるようにメソッドに分けています
  def __get_properties__(target_name, reload = false)
    @source.reload if reload
    @source.send(target_name)
  end

  def __find_and_modify__(target_name, values)
    result = Tengine::Core::Session.collection.find_and_modify({
        :query => {:_id => @source.id, :lock_version => @source.lock_version},
        :update => { target_name => values, :lock_version => @source.lock_version + 1}
      })
    result
  end


end
