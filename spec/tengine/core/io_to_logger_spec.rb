


# -*- coding: utf-8 -*-
require 'spec_helper'

require 'stringio'

describe Tengine::Core::IoToLogger do

  context "redirect from io to logger" do
    before do
      @io = StringIO.new
      @logger = Logger.new(@io)
      @logger.level = Logger::INFO
    end
    subject{ Tengine::Core::IoToLogger.new(@logger) }
    it "should provide puts method" do
      subject.puts("foo")
      @io.rewind
      @io.readlines.should == ["foo\n"]
    end
    it "should provide write method" do
      subject.write("foo")
      @io.rewind
      @io.readlines.should == ["foo\n"]
    end
  end

end
