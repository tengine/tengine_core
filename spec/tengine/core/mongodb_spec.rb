# -*- coding: utf-8 -*-
require 'spec_helper'

describe "MongoDB" do

  context "server version must be >= 2.0.x" do
    subject{ Mongoid.database.connection.server_version }
    it{ should be_a(Mongo::ServerVersion)}
    its(:to_s){ should =~ /^2\.\d+\./ }
  end

end
