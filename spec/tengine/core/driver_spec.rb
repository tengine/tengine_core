# -*- coding: utf-8 -*-
require 'spec_helper'

require 'mongoid/version'

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
      msg =
        case Mongoid::VERSION
        when /^2\.2\./ then
          "Validation failed - Name is already taken in same version."
        else
          "Validation failed - Name is already taken."
        end
      expect{
        Tengine::Core::Driver.create!(valid_attributes1)
      }.to raise_error(Mongoid::Errors::Validations, msg)
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
      @d11 = Tengine::Core::Driver.new(:name => "driver1", :version => "1", :enabled => true)
      @d11h1 = @d11.handlers.new(:event_type_names => ["foo" ], :filepath => "path/to/driver.rb", :lineno => 3)
      @d11h2 = @d11.handlers.new(:event_type_names => ["boo" ], :filepath => "path/to/driver.rb", :lineno => 5)
      @d11h3 = @d11.handlers.new(:event_type_names => ["blah"], :filepath => "path/to/driver.rb", :lineno => 7)
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
      Tengine::Core::Driver.create!(:name => "driver1", :version => "1", :enabled => true)
    end
    its(:session){ should be_a(Tengine::Core::Session)}
  end

  describe "名前で検索" do
    before do
      Tengine::Core::Setting.delete_all
      Tengine::Core::Setting.create!(:name => "dsl_version", :value => "2")
      Tengine::Core::Driver.delete_all
      Tengine::Core::Driver.create!(:name => "driver1", :version => "1", :enabled => true)
      Tengine::Core::Driver.create!(:name => "driver2", :version => "1", :enabled => true)
      Tengine::Core::Driver.create!(:name => "driver3", :version => "2", :enabled => true)
      Tengine::Core::Driver.create!(:name => "driver4", :version => "2", :enabled => true)
    end

    [:find_by_name, :find_by_name!].each do |method_name|
      context "存在する場合はそれを返す" do
        it "バージョン指定なし" do
          driver = Tengine::Core::Driver.send(method_name, "driver3")
          driver.should be_a(Tengine::Core::Driver)
          driver.name.should == "driver3"
          driver.version.should == "2"
        end

        it "バージョン指定あり" do
          driver = Tengine::Core::Driver.send(method_name, "driver1", :version => "1")
          driver.should be_a(Tengine::Core::Driver)
          driver.name.should == "driver1"
          driver.version.should == "1"
        end
      end
    end

    context ":find_by_nameは見つからなかった場合はnilを返す" do
      it "バージョン指定なし" do
        Tengine::Core::Driver.find_by_name("driver1").should == nil
      end

      it "バージョン指定あり" do
        Tengine::Core::Driver.find_by_name("driver3", :version => "1").should == nil
      end
    end

    context ":find_by_name!は見つからなかった場合はTengine::Errors::NotFoundをraiseする" do
      it "バージョン指定なし" do
        begin
          Tengine::Core::Driver.find_by_name!("driver2")
          fail
        rescue Tengine::Errors::NotFound => e
          e.message.should == "Tengine::Core::Driver named \"driver2\" not found"
        end
      end

      it "バージョン指定あり" do
        begin
          Tengine::Core::Driver.find_by_name!("driver4", :version => "1")
          fail
        rescue Tengine::Errors::NotFound => e
          e.message.should == "Tengine::Core::Driver named \"driver4\" with {:version=>\"1\"} not found"
        end
      end
    end

  end

end
