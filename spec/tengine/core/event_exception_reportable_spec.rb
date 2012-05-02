# -*- coding: utf-8 -*-
require 'spec_helper'

require 'tengine/event'

describe Tengine::Core::EventExceptionReportable do

  describe :to_reporter do
    context "Symbolで指定" do
      Tengine::Core::EventExceptionReportable::EVENT_EXCEPTION_REPORTERS.keys.each do |reporter_name|
        it reporter_name do
          Tengine::Core::EventExceptionReportable.to_reporter(reporter_name).should_not == nil
        end
      end
      it "存在しないreporter名" do
        expect{
          Tengine::Core::EventExceptionReportable.to_reporter(:unexist_reporter)
        }.to raise_error(NameError, "Unknown reporter: :unexist_reporter")
      end
    end

    it "Procを指定" do
      proc1 = Proc.new{  puts "foo" }
      Tengine::Core::EventExceptionReportable.to_reporter(proc1).should == proc1
    end

    it "不正なreporterを指定" do
      expect{
        Tengine::Core::EventExceptionReportable.to_reporter(100)
      }.to raise_error(ArgumentError, "Invalid reporter: 100")
    end
  end
end
