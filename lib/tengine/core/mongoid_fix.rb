# -*- coding: utf-8 -*-

require 'tengine_core'
require 'mongoid'
require 'mongoid/version'
require 'mongoid/cursor'

if Mongoid::VERSION < "3.0.0"
  class Mongoid::Cursor
    # https://github.com/mongoid/mongoid/pull/1609
    def each
      retry_on_connection_failure do
        while document = cursor.next
          yield Mongoid::Factory.from_db(klass, document)
        end
      end
    end
  end

  module Mongoid::Collections::Retry
    # https://github.com/mongoid/mongoid/pull/1739
    # Mongoid 2.3.x needs additional fix
    def retry_on_connection_failure
      retries = 0
      begin
        yield
      rescue Mongo::ConnectionFailure, Mongo::OperationTimeout, Mongo::OperationFailure => ex
        raise if ex.class == Mongo::OperationFailure and ex.message !~ /not master/

        retries += 1
        raise if retries > Mongoid.max_retries_on_connection_failure

        Kernel.sleep(0.5)
        log_retry retries
        retry
      end
    end
  end
end
