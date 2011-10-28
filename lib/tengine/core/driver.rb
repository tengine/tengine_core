# -*- coding: utf-8 -*-
require 'tengine/core'

# イベントドライバ
#
# イベントに対する処理はイベントハンドラによって実行されますが、イベントドライバはそのイベントハンドラの上位の概念です。
# イベントハンドラは必ずイベントドライバの中に定義されます。
#
# またイベントドライバは有効化／無効化を設定する単位であり、起動時の設定あるいはユーザーの指定によって変更することができます。
#
class Tengine::Core::Driver
  autoload :Finder, 'tengine/core/driver/finder'

  include Mongoid::Document
  include Mongoid::Timestamps
  include Tengine::Core::Validation

  # @attribute 名前
  field :name, :type => String

  # @attribute バージョン。デプロイされた際に設定されます。
  field :version, :type => String

  # @attribute 有効／無効
  field :enabled, :type => Boolean

  # @attribute 実行時有効／無効
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
