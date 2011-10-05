require 'tengine/core'

require 'active_support/core_ext/array/extract_options'

module Tengine::Core::OptimisticLock

  def update_with_lock(options = {})
    retry_count = options[:retry] || 5
    idx = 0
    begin
      yield
      __find_and_modify__
    rescue Mongo::OperationFailure => e
      idx += 1
      if idx <= retry_count
        reload
        retry
      end
      raise e
    end
  end

  def __find_and_modify__
    current_version = self.lock_version
    hash = as_document.dup
    hash['lock_version'] = current_version + 1
    self.class.collection.find_and_modify({
        :query => {:_id => self.id, :lock_version => current_version},
        :update => hash
      })
  end
end
