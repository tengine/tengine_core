# -*- coding: utf-8 -*-
class Tengine::Core::Driver
  include Mongoid::Document
  field :name, :type => String
  field :version, :type => String
  field :enabled, :type => Boolean
  field :enabled_on_activation, :type => Boolean, :default => true

  embeds_many :handlers, :class_name => "Tengine::Core::Handler"

  belongs_to :session, :index => true, :class_name => "Tengine::Core::Session"
  has_many :handler_paths, :class_name => "Tengine::Core::HandlerPath"

  after_create :update_handler_path
  before_create :create_session # has_oneによって追加されるメソッドcreate_sessionのように振る舞うメソッドです

  def update_handler_path
    handlers.each(&:update_handler_path)
  end

  def create_session
    self.session ||= Tengine::Core::Session.create
  end

end
