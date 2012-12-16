require 'yaml'
require './config'
require './errors'
require 'logger'
require 'fog'

config = YAML.load_file("../../spec/assets/sample_config.yml")
p config

p Bosh::CloudstackRegistry.configure(config)

conn = Bosh::CloudstackRegistry.cloudstack

p conn.zones