# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::CloudstackRegistry

  class ServerManager

    def initialize
      @logger = Bosh::CloudstackRegistry.logger
      @cloudstack = Bosh::CloudstackRegistry.cloudstack
    end

    ##
    # Updates server settings
    # @param [String] server_id CloudStack server id (server record
    #        will be created in DB if it doesn't already exist)
    # @param [String] settings New settings for the server
    def update_settings(server_id, settings)
      params = {
        :server_id => server_id
      }

      server = Models::CloudstackServer[params] || Models::CloudstackServer.new(params)
      server.settings = settings
      server.save
    end

    ##
    # Reads server settings
    # @param [String] server_id CloudStack server id
    def read_settings(server_id)
      get_server(server_id).settings
    end

    def delete_settings(server_id)
      get_server(server_id).destroy
    end

    private

    def get_server(server_id)
      server = Models::CloudstackServer[:server_id => server_id]

      if server.nil?
        raise ServerNotFound, "Can't find server `#{server_id}'"
      end

      server
    end

  end

end