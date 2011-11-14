# -*- coding: utf-8 -*-
require 'spec_helper'

describe Tengine::Core::Setting do
  context "nameでunique" do
    it "nameは必須" do
      expect{
        Tengine::Core::Setting.create!(:name => nil, :value => "123")
      }.to raise_error(Mongoid::Errors::Validations, "Validation failed - Name can't be blank.")
    end

    it "同じ名前のデータがなければ登録できる" do
      Tengine::Core::Setting.delete_all
      Tengine::Core::Setting.create!(:name => 'foo', :value => "123")
    end

    it "同じ名前のデータがある場合エラーになる" do
      Tengine::Core::Setting.delete_all
      Tengine::Core::Setting.create!(:name => 'foo', :value => "123")
      expect{
        Tengine::Core::Setting.create!(:name => 'foo', :value => "123")
      }.to raise_error(Mongoid::Errors::Validations, "Validation failed - Name is already taken.")
    end
  end

  describe :dsl_version do
    before do
      Tengine::Core::Setting.delete_all
    end

    context "データがない場合" do
      it "例外をraiseする" do
        expect{
          Tengine::Core::Setting.dsl_version
        }.to raise_error(Mongoid::Errors::DocumentNotFound)
      end
    end

    context "データがある場合" do
      it "値を取得する" do
        Tengine::Core::Setting.create!(:name => 'dsl_version', :value => "123456")
        Tengine::Core::Setting.dsl_version.should == "123456"
      end
    end

  end

  describe "名前で検索" do
    before do
      Tengine::Core::Setting.delete_all
      Tengine::Core::Setting.create!(:name => "setting1", :value => "a")
      Tengine::Core::Setting.create!(:name => "setting2", :value => "b")
    end

    [:find_by_name, :find_by_name!].each do |method_name|
      it "存在する場合はそれを返す" do
        driver = Tengine::Core::Setting.send(method_name, "setting1")
        driver.should be_a(Tengine::Core::Setting)
        driver.name.should == "setting1"
        driver.value.should == "a"
      end
    end

    it ":find_by_nameは見つからなかった場合はnilを返す" do
      Tengine::Core::Setting.find_by_name("unexist_setting").should == nil
    end

    it ":find_by_name!は見つからなかった場合はTengine::Core::FindByName::Errorをraiseする" do
      begin
          Tengine::Core::Setting.find_by_name!("unexist_setting")
      rescue Tengine::Errors::NotFound => e
        e.message.should == "Tengine::Core::Setting named \"unexist_setting\" not found"
      end
    end

  end


end
