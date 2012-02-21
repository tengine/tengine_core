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

    # https://github.com/mongoid/mongoid/pull/1739
    def retry_on_connection_failure
      retries = 0
      begin
        yield
      rescue Mongo::ConnectionFailure, Mongo::OperationTimeout => ex
        retries = increase_retry_attempts(retries, ex)
        retry
      rescue Mongo::OperationFailure => ex
        if ex.message =~ /not master/
          retries = increase_retry_attempts(retries, ex)
          retry
        else
          raise ex
        end
      end
    end
  end
end
