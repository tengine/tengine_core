# -*- coding: utf-8 -*-
require 'spec_helper'

describe Tengine::Core::Driver do

  valid_attributes1 = {
    :name => "driver100",
    :version => "100",
  }.freeze

  context "nameとversionは必須" do
    it "正常系" do
      Tengine::Core::Driver.delete_all
      driver1 = Tengine::Core::Driver.new(valid_attributes1)
      driver1.valid?.should == true
    end

    [:name, :version].each do |key|
      it "#{key}なし" do
        attrs = valid_attributes1.dup
        attrs.delete(key)
        driver1 = Tengine::Core::Driver.new(attrs)
        driver1.valid?.should == false
      end
    end
  end

  context "nameはバージョン毎にユニーク" do
    before do
      Tengine::Core::Driver.delete_all
      Tengine::Core::Driver.create!(valid_attributes1)
    end

    it "同じ名前で登録されているものが存在する場合エラー" do
      expect{
        Tengine::Core::Driver.create!(valid_attributes1)
      }.to raise_error(Mongoid::Errors::Validations, "Validation failed - Name is already taken in same version.")
    end

    it "同じバージョンでも異なる名前ならばOK" do
      Tengine::Core::Driver.create!(valid_attributes1.merge(:name => "driver200"))
    end

    it "同じ名前でも異なるバージョンならばOK" do
      Tengine::Core::Driver.create!(valid_attributes1.merge(:version => "101"))
    end
  end

  context "nameのフォーマットはベース名に準拠する" do
    it "スラッシュ'/’はリソース識別子で使われるのでnameには使用できません" do
      driver1 = Tengine::Core::Driver.new(:name => "foo/bar")
      driver1.valid?.should == false
      driver1.errors[:name].should == [Tengine::Core::Validation::BASE_NAME.message]
    end

    it "コロン':'はリソース識別子で使われるのでnameには使用できません" do
      driver1 = Tengine::Core::Driver.new(:name => "foo:bar")
      driver1.valid?.should == false
      driver1.errors[:name].should == [Tengine::Core::Validation::BASE_NAME.message]
    end
  end

  context "保存時にHandlerPathを自動的に登録します" do
    before do
      Tengine::Core::Driver.delete_all
      Tengine::Core::HandlerPath.delete_all
      @d11 = Tengine::Core::Driver.new(name:"driver1", version:"1", enabled:true)
      @d11h1 = @d11.handlers.new(:event_type_names => ["foo"])
      @d11h2 = @d11.handlers.new(:event_type_names => ["boo"])
      @d11h3 = @d11.handlers.new(:event_type_names => ["blah"])
      @d11.save!
    end
    it do
      Tengine::Core::HandlerPath.count.should == 3
      Tengine::Core::HandlerPath.event_type_name("foo").map(&:handler_id).should == [@d11h1.id]
      Tengine::Core::HandlerPath.event_type_name("boo").map(&:handler_id).should == [@d11h2.id]
      Tengine::Core::HandlerPath.event_type_name("blah").map(&:handler_id).should == [@d11h3.id]
    end
  end

  context "must have only one session" do
    subject do
      Tengine::Core::Driver.delete_all
      Tengine::Core::Driver.create!(name:"driver1", version:"1", enabled:true)
    end
    its(:session){ should be_a(Tengine::Core::Session)}
  end

end
