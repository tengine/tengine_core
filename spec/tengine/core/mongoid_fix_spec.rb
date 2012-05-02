# -*- coding: utf-8 -*-
require 'spec_helper'
require 'tengine/core/mongoid_fix'

describe Mongoid::Cursor do

  class TestDocument
    include Mongoid::Document
  end

  [
   Mongo::ConnectionFailure,
   Mongo::OperationTimeout,
   Mongo::OperationFailure
  ].each do |e|

    context e do

      subject { TestDocument.all }

      before(:all) { TestDocument.new.save }

      before do
        ex = e.new "not master"
        @m = Mongoid.max_retries_on_connection_failure
        Mongoid.max_retries_on_connection_failure = 32
        n = 0
        Mongo::Cursor.any_instance.stub(:next) do
          n += 1
          raise ex while n < 1
          nil
        end
      end

      after do
        Mongoid.max_retries_on_connection_failure = @m
#        Mongo::Cursor.any_instance.unstub(:next)
        TestDocument.delete_all
      end

      it do
        begin
          subject.to_a
        rescue Exception
          puts $!.backtrace
        end
      end
      # its(:to_a) { should be_empty }
    end
  end

end
