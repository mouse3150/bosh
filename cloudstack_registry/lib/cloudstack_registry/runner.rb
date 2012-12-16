# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::CloudstackRegistry
  class Runner
    include YamlHelper

    def initialize(config_file)
      Bosh::CloudstackRegistry.configure(load_yaml_file(config_file))

      @logger = Bosh::CloudstackRegistry.logger
    end

    def run
      @logger.info("BOSH CloudStack Registry starting...")
      EM.kqueue if EM.kqueue?
      EM.epoll if EM.epoll?

      EM.error_handler { |e| handle_em_error(e) }

      EM.run do
        start_http_server
      end
    end

    def stop
      @logger.info("BOSH CloudStack Registry shutting down...")
      @http_server.stop! if @http_server
      EM.stop
    end

    def start_http_server
      @logger.info "HTTP server is starting on port #{@http_port}..."
      @http_server = Thin::Server.new("0.0.0.0", @http_port, :signals => false) do
        Thin::Logging.silent = true
        map "/" do
          run Bosh::CloudstackRegistry::ApiController.new
        end
      end
      @http_server.start!
    end

    private

    def handle_em_error(e, level = :fatal)
      @logger.send(level, e.to_s)
      if e.respond_to?(:backtrace) && e.backtrace.respond_to?(:join)
        @logger.send(level, e.backtrace.join("\n"))
      end
      stop
    end

  end
end