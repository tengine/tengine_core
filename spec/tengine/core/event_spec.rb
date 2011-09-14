require 'spec_helper'

describe Tengine::Core::Event do
  context "must be unique with key and sender_name" do
    it "raise an exception when violate unique consistent" do
      Mongoid.persist_in_safe_mode.should == true

      unique_key_name = "key1"
      Tengine::Core::Event.delete_all
      Tengine::Core::Event.create!(:event_type_name => "foo", :key => unique_key_name, :sender_name => "server1")
      expect {
        Tengine::Core::Event.create!(:event_type_name => "foo", :key => unique_key_name, :sender_name => "server2")
      }.to raise_error # (Mongo::OperationFailure, /duplicate key error/)
    end
  end
end
