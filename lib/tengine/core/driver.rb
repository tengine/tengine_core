# -*- coding: utf-8 -*-
require 'tengine/core'

class Tengine::Core::Driver
  autoload :Finder, 'tengine/core/driver/finder'

  include Mongoid::Document
  include Mongoid::Timestamps
  include Tengine::Core::Validation

  field :name, :type => String
  field :version, :type => String
  field :enabled, :type => Boolean
  field :enabled_on_activation, :type => Boolean, :default => true

  validates(:name, :presence => true,
    :uniqueness => {:scope => :version, :message => "is already taken in same version"},
    :format => BASE_NAME.options
    )
  validates :version, :presence => true

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
