# Copyright (c) 2009-2012 VMware, Inc.

module Bosh
  module CloudstackRegistry
    autoload :Models, "cloudstack_registry/models"
  end
end

require "fog"
require "logger"
require "sequel"
require "sinatra/base"
require "thin"
require "yajl"

require "cloudstack_registry/yaml_helper"

require "cloudstack_registry/api_controller"
require "cloudstack_registry/config"
require "cloudstack_registry/errors"
require "cloudstack_registry/server_manager"
require "cloudstack_registry/runner"
require "cloudstack_registry/version"

Sequel::Model.plugin :validation_helpers