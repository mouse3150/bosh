# Copyright (c) 2009-2012 VMware, Inc.

require File.dirname(__FILE__) + "/lib/cloudstack_registry/version"

Gem::Specification.new do |s|
  s.name         = "bosh_cloudstack_registry"
  s.version      = Bosh::CloudstackRegistry::VERSION
  s.platform     = Gem::Platform::RUBY
  s.summary      = "BOSH CloudStack registry"
  s.description  = s.summary
  s.author       = "VMware"
  s.email        = "support@vmware.com"
  s.homepage     = "http://www.vmware.com"

  s.files        = `git ls-files -- bin/* lib/*`.split("\n") + %w(README Rakefile)
  s.test_files   = `git ls-files -- spec/*`.split("\n")
  s.require_path = "lib"
  s.bindir       = "bin"
  s.executables  = %w(cloudstack_registry)

  s.add_dependency "sequel"
  s.add_dependency "sinatra"
  s.add_dependency "thin"
  s.add_dependency "yajl-ruby"
  s.add_dependency "fog", "~>1.8.0"
end
