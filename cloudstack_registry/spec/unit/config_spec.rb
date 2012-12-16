# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::CloudstackRegistry do

  describe "configuring CloudStack registry" do
    it "reads provided configuration file and sets singletons" do
      Bosh::CloudstackRegistry.configure(valid_config)

      logger = Bosh::CloudstackRegistry.logger

      logger.should be_kind_of(Logger)
      logger.level.should == Logger::DEBUG

      Bosh::CloudstackRegistry.http_port.should == 25777
      Bosh::CloudstackRegistry.http_user.should == "admin"
      Bosh::CloudstackRegistry.http_password.should == "admin"

      db = Bosh::CloudstackRegistry.db
      db.should be_kind_of(Sequel::SQLite::Database)
      db.opts[:database].should == "/:memory:"
      db.opts[:max_connections].should == 433
      db.opts[:pool_timeout].should == 227
    end

    it "validates configuration file" do
      expect {
        Bosh::CloudstackRegistry.configure("foobar")
      }.to raise_error(Bosh::CloudstackRegistry::ConfigError,
                       /Invalid config format/)

      config = valid_config.merge("http" => nil)

      expect {
        Bosh::CloudstackRegistry.configure(config)
      }.to raise_error(Bosh::CloudstackRegistry::ConfigError,
                       /HTTP configuration is missing/)

      config = valid_config.merge("db" => nil)

      expect {
        Bosh::CloudstackRegistry.configure(config)
      }.to raise_error(Bosh::CloudstackRegistry::ConfigError,
                       /Database configuration is missing/)

      config = valid_config.merge("cloudstack" => nil)

      expect {
        Bosh::CloudstackRegistry.configure(config)
      }.to raise_error(Bosh::CloudstackRegistry::ConfigError,
                       /CloudStack configuration is missing/)
    end

  end
end
