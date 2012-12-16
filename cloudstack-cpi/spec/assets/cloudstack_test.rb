require 'rubygems'
require 'fog'

# create a connection
connection = Fog::Compute.new({
  :provider => "cloudstack",
  :cloudstack_host => "168.1.43.14",
  :cloudstack_port => "8080",
  :cloudstack_api_key => "hHdIgGdz6V-6I9Dc0dqhgUKutGJX-7_XTurvjd89SWAXPFiMZEy_Gb0uGfzbTyzS1rrdcwwZq81nxWS3UW8IcQ",
  :cloudstack_secret_access_key => "zKao312dFgDKFdSI04Kh2axSuiWDXLDXj848GFxXRvRZPjiEuA6UfQq4uGdEHxrvuaYoNpv3_SBWfRqX6lPIwg",
  #:cloudstack_api_key => "admin",
  #:cloudstack_secret_access_key => "admin",
  :cloudstack_scheme => "http"
  #:vsphere_expected_pubkey_hash => "df8c0a3223a9b492e53ca8fc88fa40656df7514de41f8d172b04710f774537b0"
})

# p server = connection.register_template({
  # :displaytext => 'displaytext',
  # :format => 'VHD',
  # :hypervisor => 'XenServer',
  # :name => 'fromfog_tem',
  # :ostypeid => '126',
  # :url => 'http://168.1.43.101/8f598161-ffdb-4f07-82d4-9944e719e924.vhd.bz2',
  # :zoneid => 'f89151dd-6677-4b2e-abf1-7a324191a324'
# })
# p server = connection.delete_template({"id" => "0f5443ac-e007-46f1-bd97-f626c3fa81e7"})

#p server = connection.servers.stop({:id => '090cebb7-f098-440d-a7dd-c34690719818'})

#p server = connection.servers.get('090cebb7-f098-440d-a7dd-c34690719818')
#p server.id

#p connection.images.all#("c316dd7d-f2d5-49d9-a5bc-b4e874869d8a")

#image = Fog::Compute::Cloudstack::Image.new({:id => 'c316dd7d-f2d5-49d9-a5bc-b4e874869d8a'})
#p image
#image.destroy

#p connection.image.destroy({:id => 'c316dd7d-f2d5-49d9-a5bc-b4e874869d8a'}) error

#p image = connection.images.get('c316dd7d-f2d5-49d9-a5bc-b4e874869d8a')
#p image = connection.images.get('c316dd7d-f2d5-49d9-a5bc-')

#p vm = connection.servers.all#get('c316dd7d-f2d5-49d9-a5bc-b4e874869d8a')
#p vm = connection.servers.get("090cebb7-f098-440d-a7dd-c34690719818")
#vm.start

# temp_params = {
   # :display_text => 'displaytext',
   # :format => 'VHD',
   # :hypervisor => 'XenServer',
   # :name => 'fromfog_tem2',
   # :os_type_id => '126',
   # :url => 'http://168.1.43.101/8f598161-ffdb-4f07-82d4-9944e719e924.vhd.bz2',
   # :zone_id => 'f89151dd-6677-4b2e-abf1-7a324191a324'
# }
# 
# p vm = connection.images.register(temp_params)


###deploy virtual machine
#server = connection.deploy_virtual_machine({
#  'zoneid' => 'f89151dd-6677-4b2e-abf1-7a324191a324',
#  'templateid' => '64918891-624d-49c8-9aee-f38a14024d1f',
#  'serviceofferingid' => '5e99a1e5-c848-425c-a41a-c39400cc3c0f',
#  'displayname' => 'fromfog'
#})

# vm_params = {
  # 'zoneid' => 'f89151dd-6677-4b2e-abf1-7a324191a324',
  # 'templateid' => '2685077d-c46d-4b08-8a0e-f707dd708d3d',
  # 'serviceofferingid' => '5e99a1e5-c848-425c-a41a-c39400cc3c0f',
  # 'displayname' => 'fromfog'
# }
# 
# p server = connection.servers.create(vm_params)


#p flavor = connection.flavors


#p flavor = connection.volumes.all

# volume_params = {
  # :name => "new_created_2",
  # #:disk_offering_id => "6842ec8d-26dd-47be-bdc4-de5521e804f7",
  # :zone_id => "f89151dd-6677-4b2e-abf1-7a324191a324"
# }
# p connection.volumes.create(volume_params)
p connection.servers.get("06538a18-194d-41f6-a061-bd8d8c43135a")
