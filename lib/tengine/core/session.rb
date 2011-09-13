# -*- coding: utf-8 -*-
class Tengine::Core::Session
  include Mongoid::Document
  field :lock_version, :type => Integer, :default => 1
  field :properties, :type => Hash, :default => {}
  map_yaml_accessor :properties
  field :system_properties, :type => Hash, :default => {}
  map_yaml_accessor :system_properties

  has_one :driver, :class_name => "Tengine::Core::Driver"

  # 元々の[]と[]=メソッドをオーバーライドしているので要注意
  def [](key); properties[key]; end
  def []=(key, value); properties[key] = value; end
end
