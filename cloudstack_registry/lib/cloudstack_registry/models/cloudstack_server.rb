# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::CloudStackRegistry::Models
  class CloudstackServer < Sequel::Model

    def validate
      validates_presence [:server_id, :settings]
      validates_unique :server_id
    end

  end
end