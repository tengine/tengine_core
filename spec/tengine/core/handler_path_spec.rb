require 'spec_helper'

describe Tengine::Core::HandlerPath do

  describe :find_handlers do
    before do
      Tengine::Core::Driver.delete_all
      @d11 = Tengine::Core::Driver.find_or_create_by(name:"driver1", version:"1", enabled:true)
      @d11h1 = @d11.handlers.find_or_create_by(:event_type_names => ["foo"])
      @d11h2 = @d11.handlers.find_or_create_by(:event_type_names => ["boo"])
      @d11h3 = @d11.handlers.find_or_create_by(:event_type_names => ["blah"])
      Tengine::Core::HandlerPath.create(:event_type_name => "foo", :driver => @d11, :handler_id => @d11h1.id)
      Tengine::Core::HandlerPath.create(:event_type_name => "boo", :driver => @d11, :handler_id => @d11h2.id)
      Tengine::Core::HandlerPath.create(:event_type_name => "blah", :driver => @d11, :handler_id => @d11h3.id)
      @d21 = Tengine::Core::Driver.find_or_create_by(name:"driver1", version:"2", enabled:true)
      @d21h1 = @d21.handlers.find_or_create_by(:event_type_names => ["foo"])
      @d21h2 = @d21.handlers.find_or_create_by(:event_type_names => ["boo"])
      Tengine::Core::HandlerPath.create(:event_type_name => "foo", :driver => @d21, :handler_id => @d21h1.id)
      Tengine::Core::HandlerPath.create(:event_type_name => "boo", :driver => @d21, :handler_id => @d21h2.id)
      @d22 = Tengine::Core::Driver.find_or_create_by(name:"driver2", version:"2", enabled:true)
      @d22h1 = @d22.handlers.find_or_create_by(:event_type_names => ["foo"])
      @d22h2 = @d22.handlers.find_or_create_by(:event_type_names => ["bar"])
      Tengine::Core::HandlerPath.create(:event_type_name => "foo", :driver => @d22, :handler_id => @d22h1.id)
      Tengine::Core::HandlerPath.create(:event_type_name => "bar", :driver => @d22, :handler_id => @d22h2.id)
      @d23 = Tengine::Core::Driver.find_or_create_by(name:"driver3", version:"2", enabled:false)
      @d23h1 = @d23.handlers.find_or_create_by(:event_type_names => ["bar"])
      @d23h2 = @d23.handlers.find_or_create_by(:event_type_names => ["baz"])
      Tengine::Core::HandlerPath.create(:event_type_name => "bar", :driver => @d23, :handler_id => @d23h1.id)
      Tengine::Core::HandlerPath.create(:event_type_name => "baz", :driver => @d23, :handler_id => @d23h2.id)
    end

    context "with default_driver_version" do
      it "should return handlers" do
        Tengine::Core::HandlerPath.default_driver_version = "2"
        Tengine::Core::HandlerPath.find_handlers("foo").map(&:id).should == [@d21h1.id, @d22h1.id]
        Tengine::Core::HandlerPath.find_handlers("boo").map(&:id).should == [@d21h2.id]
        Tengine::Core::HandlerPath.find_handlers("bar").map(&:id).should == [@d22h2.id]
        Tengine::Core::HandlerPath.find_handlers("baz").map(&:id).should == []
        Tengine::Core::HandlerPath.find_handlers("FOO").map(&:id).should == []
        Tengine::Core::HandlerPath.find_handlers("blah").map(&:id).should == []
      end

      it "should return old handlers" do
        Tengine::Core::HandlerPath.default_driver_version = "1"
        Tengine::Core::HandlerPath.find_handlers("foo").map(&:id).should == [@d11h1.id]
        Tengine::Core::HandlerPath.find_handlers("boo").map(&:id).should == [@d11h2.id]
        Tengine::Core::HandlerPath.find_handlers("blah").map(&:id).should == [@d11h3.id]
        Tengine::Core::HandlerPath.find_handlers("bar").map(&:id).should == []
        Tengine::Core::HandlerPath.find_handlers("baz").map(&:id).should == []
      end
    end

    context "generated handler_paths" do
      before do
        Tengine::Core::Driver.delete_all
        Tengine::Core::HandlerPath.delete_all
      end

      it "should return handlers for enabled driver" do
        @driver = Tengine::Core::Driver.new(:name => "driver01", :version => "123", :enabled => true)
        @handler1 = @driver.handlers.new(:event_type_names => ["event01"])
        @driver.save!

        Tengine::Core::HandlerPath.all.count.should == 1
        Tengine::Core::HandlerPath.default_driver_version = "123"
        handlers = Tengine::Core::HandlerPath.find_handlers("event01")
        handlers.count.should == 1
        handlers.each do |handler|
          handler.id.should == @handler1.id
        end
      end

      it "should return handlers for disabled driver" do
        @driver = Tengine::Core::Driver.new(:name => "driver01", :version => "123", :enabled => false)
        @handler1 = @driver.handlers.new(:event_type_names => ["event01"])
        @driver.save!

        Tengine::Core::HandlerPath.all.count.should == 1
        Tengine::Core::HandlerPath.default_driver_version = "123"
        Tengine::Core::HandlerPath.find_handlers("event01").count.should == 0
      end
    end
  end

end
