require 'tengine/core'

module Tengine::Core::SafeUpdatable
  extend ActiveSupport::Concern

  module InstanceMethods
    def update_in_safe_mode(collection, selector, document, opts=nil)
      options = { :upsert => false, :multiple => false }
      options.update(opts) if opts

      options = options.merge({ :safe => safemode(collection, 1024) })

      max_retries = 100
      retries = 0
      begin
        # Return a Hash containing the last error object if running safe mode.
        # Otherwise, returns true
        result = collection.driver.update(selector, document, options)
      rescue Mongo::ConnectionFailure, Mongo::OperationFailure => ex
        case ex when Mongo::OperationFailure then
          raise ex unless ex.message =~ /wtimeout/
        end
        retries += 1
        raise ex if retries > max_retries
        Tengine.logger.debug "retrying due to mongodb error #{ex.inspect}"
        sleep 0.5
        retry
      end
    end

    def safemode(collection, wtimeout=61440)
      res = true
      case collection.driver.db.connection when Mongo::ReplSetConnection then
        res = { :w => "majority", :wtimeout => wtimeout, }
      end
      res
    end
  end
end
