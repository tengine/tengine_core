require 'tengine/core'

require 'active_support/core_ext/array/extract_options'

module Tengine::Core::OptimisticLock

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
    current_version = self.lock_version
    hash = as_document.dup
    hash['lock_version'] = current_version + 1
    result = self.class.collection.find_and_modify({
        :query => {:_id => self.id, :lock_version => current_version},
        :update => hash
      })
    result
  end
end
