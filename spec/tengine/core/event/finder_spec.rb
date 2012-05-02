# -*- coding: utf-8 -*-
require 'spec_helper'

describe Tengine::Core::Event::Finder do

  context "検索" do
    before(:all) do
      Tengine::Core::Event.delete_all
      occured_at_base = Time.now
      base = {
        :sender_name => "agent:server1/99326/tengine_job_agent",
        :level => 2,
      }
      uuid_gen = Tengine::Event.uuid_gen
      [
        {:event_type_name => "start.execution.job.tengine", :source_name => "execution:localhost/123/1111/1111"}.update(base),
        {:event_type_name => "start.jobnet.job.tengine", :source_name => "job:localhost/123/2222/3333"}.update(base),
        {:event_type_name => "start.job.job.tengine", :source_name => "job:localhost/123/2222/4444"}.update(base),
        {:event_type_name => "finished.process.job.tengine", :source_name => "job:localhost/123/2222/4444"}.update(base),
        {:event_type_name => "success.job.job.tengine", :source_name => "job:localhost/123/2222/4444"}.update(base),
        {:event_type_name => "success.jobnet.job.tengine", :source_name => "job:localhost/123/2222/3333"}.update(base),
        {:event_type_name => "success.execution.job.tengine", :source_name => "execution:localhost/123/1111/1111"}.update(base),
      ].each_with_index do |attrs, i|
        Tengine::Core::Event.create!(attrs.update(:key => uuid_gen.generate, :occurred_at => occured_at_base + (i*10)))
      end
    end


    context "event_type_name" do
      it ".jobnet.job.tengine" do
        f = Tengine::Core::Event::Finder.new(:event_type_name => "/.jobnet.job.tengine$/")
        result = f.paginate
        result.map{|h| h[:event_type_name]}.should == [
          "success.jobnet.job.tengine",
          "start.jobnet.job.tengine",
        ]
      end

      it "start.job." do
        f = Tengine::Core::Event::Finder.new(:event_type_name => "start.job.")
        result = f.paginate
        result.map{|h| h[:event_type_name]}.should == [
          "start.job.job.tengine",
        ]
      end

      it "/start.job./" do
        f = Tengine::Core::Event::Finder.new(:event_type_name => "/start.job./")
        result = f.paginate
        result.map{|h| h[:event_type_name]}.should == [
          "start.job.job.tengine",
          "start.jobnet.job.tengine",
        ]
      end
    end

    context "source_name" do
      it "execution" do
        f = Tengine::Core::Event::Finder.new(:source_name => "execution:localhost/123")
        result = f.paginate
        result.map{|h| h[:event_type_name]}.should == [
          "success.execution.job.tengine",
          "start.execution.job.tengine",
        ]
      end

      it "job" do
        f = Tengine::Core::Event::Finder.new(:source_name => "job:localhost/123/2222")
        result = f.paginate
        result.map{|h| h[:event_type_name]}.should == [
          "success.jobnet.job.tengine",
          "success.job.job.tengine",
          "finished.process.job.tengine",
          "start.job.job.tengine",
          "start.jobnet.job.tengine",
        ]
      end
    end

    context "sender_name" do
      it "string" do
        f = Tengine::Core::Event::Finder.new(:sender_name => "server1")
        result = f.paginate
        result.map{|h| h[:event_type_name]}.should == []
      end

      it "regexp" do
        f = Tengine::Core::Event::Finder.new(:sender_name => "/server1/")
        result = f.paginate
        result.map{|h| h[:event_type_name]}.should == [
          "success.execution.job.tengine",
          "success.jobnet.job.tengine",
          "success.job.job.tengine",
          "finished.process.job.tengine",
          "start.job.job.tengine",
          "start.jobnet.job.tengine",
          "start.execution.job.tengine",
        ]
      end
    end

    context "scope" do
      it "ソート順は発生時刻の降順であること" do
        f = Tengine::Core::Event::Finder.new
        result = f.paginate
        result.map{|h| h[:event_type_name]}.should == [
          "success.execution.job.tengine",
          "success.jobnet.job.tengine",
          "success.job.job.tengine",
          "finished.process.job.tengine",
          "start.job.job.tengine",
          "start.jobnet.job.tengine",
          "start.execution.job.tengine",
        ]

        occurred_at_base = Time.now
        result.each_with_index do |event, i|
          event.occurred_at = occurred_at_base + i
          event.save!
        end

        f = Tengine::Core::Event::Finder.new
        result = f.paginate
        result.map{|h| h[:event_type_name]}.should == [
          "start.execution.job.tengine",
          "start.jobnet.job.tengine",
          "start.job.job.tengine",
          "finished.process.job.tengine",
          "success.job.job.tengine",
          "success.jobnet.job.tengine",
          "success.execution.job.tengine",
        ]
      end
    end
  end
end
