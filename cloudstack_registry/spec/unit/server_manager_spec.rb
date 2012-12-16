# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::CloudstackRegistry::ServerManager do

  before(:each) do
    cloudstack = double(Fog::Compute)
    Fog::Compute.stub(:new).and_return(cloudstack)
    @cloudstack = mock("cloudstack")
    Bosh::CloudstackRegistry.cloudstack = @cloudstack
  end

  let(:manager) do
    Bosh::CloudstackRegistry::ServerManager.new
  end

  def create_server(params)
    Bosh::CloudstackRegistry::Models::CloudstackServer.create(params)
  end

  describe "reading settings" do
    it "returns settings" do
      create_server(:server_id => "foo", :settings => "bar")
      manager.read_settings("foo").should == "bar"
    end

    it "raises an error if server not found" do
      expect {
        manager.read_settings("foo")
      }.to raise_error(Bosh::CloudstackRegistry::ServerNotFound,
                       "Can't find server `foo'")
    end
  end

  describe "updating settings" do
    it "updates settings (new server)" do
      manager.update_settings("foo", "baz")
      manager.read_settings("foo").should == "baz"
    end

    it "updates settings (existing server)" do
      create_server(:server_id => "foo", :settings => "bar")
      manager.read_settings("foo").should == "bar"
      manager.update_settings("foo", "baz")
      manager.read_settings("foo").should == "baz"
    end
  end

  describe "deleting settings" do
    it "deletes settings" do
      manager.update_settings("foo", "baz")
      manager.delete_settings("foo")

      expect {
        manager.read_settings("foo")
      }.to raise_error(Bosh::CloudstackRegistry::ServerNotFound,
                       "Can't find server `foo'")
    end

    it "raises an error if server not found" do
      expect {
        manager.delete_settings("foo")
      }.to raise_error(Bosh::CloudstackRegistry::ServerNotFound,
                       "Can't find server `foo'")
    end
  end

end
