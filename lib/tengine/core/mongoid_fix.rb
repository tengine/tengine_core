# -*- coding: utf-8 -*-
require 'tengine_core'
require 'mongoid'
require 'mongoid/version'
require 'mongoid/cursor'

if Mongoid::VERSION <= "3.0.0"
  class Mongoid::Cursor
    # https://github.com/mongoid/mongoid/pull/1609
    def each
      loop do
        retry_on_connection_failure do
          return unless document = cursor.next
          yield Mongoid::Factory.from_db(klass, document)
        end
      end
    end
  end
end
