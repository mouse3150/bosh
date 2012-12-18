# Copyright (c) 2012 Tongtech, Inc.

module Bosh::CloudStackCloud
  ##
  # BOSH CloudStack CPI
  class Cloud < Bosh::Cloud
    include Helpers

    attr_reader :cloudstack
    attr_reader :registry
    attr_accessor :logger

    ##
    # Creates a new BOSH CloudStack CPI
    #
    # @param [Hash] options CPI options
    # @option options [Hash] cloudstack CloudStack specific options
    # @option options [Hash] agent agent options
    # @option options [Hash] registry agent options
    def initialize(options)
      @options = options.dup

      validate_options

      @logger = Bosh::Clouds::Config.logger

      @agent_properties = @options["agent"] || {}
      @cloudstack_properties = @options["cloudstack"]
      @registry_properties = @options["registry"]

      @default_security_groups = @cloudstack_properties["default_security_groups"]

      cloudstack_params = {
        :provider => "CloudStack",
        :cloudstack_host => @cloudstack_properties["cloudstack_host"],
        :cloudstack_port => @cloudstack_properties["cloudstack_port"],
        :cloudstack_api_key => @cloudstack_properties["cloudstack_api_key"],
        :cloudstack_secret_access_key => @cloudstack_properties["cloudstack_secret_access_key"],
        :cloudstack_scheme => @cloudstack_properties["cloudstack_scheme"]
      }
      @cloudstack = Fog::Compute.new(cloudstack_params)

      registry_endpoint = @registry_properties["endpoint"]
      registry_user = @registry_properties["user"]
      registry_password = @registry_properties["password"]
      @registry = RegistryClient.new(registry_endpoint,
                                     registry_user,
                                     registry_password)

      @metadata_lock = Mutex.new
    end

    ##
    # Creates a new CloudStack Template using stemcell image. 
    #
    def create_stemcell(image_path, cloud_properties)
      with_thread_name("create_stemcell(#{image_path}...)") do
        begin
          options = {
            'displaytext' => cloud_properties['displaytext'],
            'format' => cloud_properties['format'],
            'hypervisor' => cloud_properties['hypervisor'],
            'name' => cloud_properties['name'],
            'ostypeid' => cloud_properties['ostypeid'],
            'url' => cloud_properties['url'],
            'zoneid' => cloud_properties['zoneid']
          }
          
          response = @cloudstack.register_template(options)
          stemcell_id = response['registertemplateresponse']['template']['id']
        rescue => e
          @logger.error(e)
          raise e
        end
      end
    end

    ##
    # Deletes a stemcell
    #
    # @param [String] stemcell_id CloudStack template UUID of the stemcell to be
    #   deleted
    # @return [void]
    def delete_stemcell(stemcell_id)
      with_thread_name("delete_stemcell(#{stemcell_id})") do
        @logger.info("Deleting stemcell `#{stemcell_id}'...")
        template = @cloudstack.images.get(stemcell_id)
        if template
          template.destroy
          @logger.info("Stemcell `#{stemcell_id}' is deleted")
        else
          @logger.info("Stemcell `#{stemcell_id}' can not found. Skipping")
        end
      end
    end

    ##
    # Creates an CloudStack vm and waits until it's in running state
    #
    # @param [String] agent_id UUID for the agent that will be used later on by
    #   the director to locate and talk to the agent
    # @param [String] stemcell_id CloudStack image UUID that will be used to
    #   power on new server
    # @param [Hash] resource_pool cloud specific properties describing the
    #   resources needed for this VM
    # @param [Hash] networks list of networks and their settings needed for
    #   this VM
    # @param [optional, Array] disk_locality List of disks that might be
    #   attached to this server in the future, can be used as a placement
    #   hint (i.e. server will only be created if resource pool availability
    #   zone is the same as disk availability zone)
    # @param [optional, Hash] environment Data to be merged into agent settings
    # @return [String] CloudStack server UUID
    #config require serviceofferingid(resoure type)|zoneid|securitygroup etc.
    def create_vm(agent_id, stemcell_id, config,
                  network_spec = nil, disk_locality = nil, environment = nil)
      with_thread_name("create_vm(#{agent_id}, ...)") do

        server_name = "vm-#{generate_unique_name}"
        user_data = {
          "registry" => {
            "endpoint" => @registry.endpoint
          },
          "server" => {
            "name" => server_name
          }
        }

        #make sure the template exist
        template = @cloudstack.images.get(stemcell_id)
        
        unless template
          cloud_error("Template `#{stemcell_id}' not found")
        end 
        
        @logger.debug("Using template: `#{stemcell_id}'")
        
        flavor = @cloudstack.flavors.find { |f|
          f.name == config["instance_type"] }
        if flavor.nil?
          cloud_error("Flavor `#{config["instance_type"]}' not found")
        end
        @logger.debug("Using flavor: `#{config["instance_type"]}'")
        
        vm_params = {
          #requires
          :flavor_id => flavor.id,
          :image_id => stemcell_id,
          :zone_id => config['zoneid'],
          
          #options
          :display_name => server_name,
          :user_data => Yajl::Encoder.encode(user_data)
        }

        if @default_security_groups || config["securitygroupid"]
          vm_params[:securitygroupids] = @default_security_groups ? @default_security_groups : config["securitygroupid"]
        end
        
        if config["ipaddress"]
          vm_params[:ip_address] = config["ipaddress"]
        end
        
        begin
          vm = @cloudstack.servers.create(vm_params)
        rescue => e
          @logger.error(e)
          raise e
        end
        
        if vm
          @logger.info("Updating settings for server `#{server.id}'...")
          settings = initial_agent_settings(server_name, vm.id,  agent_id, network_spec,
                                            environment)
          @registry.update_settings(vm.diplay_name, settings)
  
          vm.id.to_s
        end

      end
    end

    ##
    # Terminates an CloudStack server and waits until it reports as terminated
    #
    # @param [String] server_id CloudStack vm UUID
    # @return [void]
    def delete_vm(vm_id)
      with_thread_name("delete_vm(#{vm_id})") do
        @logger.info("Deleting server `#{vm_id}'...")
        server = @cloudstack.servers.get(vm_id)
        if server
          server.destroy
          wait_resource(server, :running, :state, true)

          @logger.info("Deleting settings for vm `#{server.id}'...")
          @registry.delete_settings(server.name)
        else
          @logger.info("vm `#{vm_id}' not found. Skipping.")
        end
      end
    end

    ##
    # Reboots an CloudStack Vm
    #
    # @param [String] server_id Cloudstack vm UUID
    # @return [void]
    def reboot_vm(vm_id)
      with_thread_name("reboot_vm(#{vm_id})") do
        server = @cloudstack.servers.get(vm_id)
        unless server
          cloud_error("Server `#{vm_id}' not found")
        end
        soft_reboot(server)
      end
    end

    ##
    # Configures networking on existing CloudStack server
    #
    # @param [String] server_id CloudStack server UUID
    # @param [Hash] network_spec Raw network spec passed by director
    # @return [void]
    # @raise [Bosh::Clouds:NotSupported] if the security groups change
    def configure_networks(server_id, network_spec)
      not_implemented(:configure_networks)
    end

    ##
    # Creates a new CloudStack volume
    #
    # @param [Integer] size disk size in MiB
    # @param [optional, String] server_id CloudStack server UUID of the VM that
    #   this disk will be attached to
    # @return [String] CloudStack volume UUID
    def create_disk(size, server_id = nil)
      with_thread_name("create_disk(#{size}, #{server_id})") do
        unless size.kind_of?(Integer)
          raise ArgumentError, "Disk size needs to be an integer"
        end

        if (size < 1024)
          cloud_error("Minimum disk size is 1 GiB")
        end

        if (size > 1024 * 1000)
          cloud_error("Maximum disk size is 1 TiB")
        end
        #cloudstack create volume fog require :name,:disk_offering_id,:zone_id
        #TODO need fetch disk_offering_id
        volume_params = {
          :name => "volume-#{generate_unique_name}",
          :disk_offering_id => "",
          :zone_id => "",
          :size => (size / 1024.0).ceil,
        }

        if server_id
          server = @cloudstack.servers.get(server_id)
          if server && server.availability_zone
            volume_params[:availability_zone] = server.availability_zone
          end
        end

        @logger.info("Creating new volume...")
        volume = @cloudstack.volumes.create(volume_params)

        @logger.info("Creating new volume `#{volume.id}'...")
        wait_resource(volume, :available)
        
        volume.id.to_s
      end
    end

    ##
    # Deletes an CloudStack volume
    #
    # @param [String] disk_id OpenStack volume UUID
    # @return [void]
    # @raise [Bosh::Clouds::CloudError] if disk is not in available state
    def delete_disk(disk_id)
      with_thread_name("delete_disk(#{disk_id})") do
        @logger.info("Deleting volume `#{disk_id}'...")
        volume = @cloudstack.volumes.get(disk_id)
        if volume
          state = volume.state
          if !state.ready?
            cloud_error("Cannot delete volume `#{disk_id}', state is #{state}")
          end

          volume.destroy
          wait_resource(volume, :deleted, :status, true)
        else
          @logger.info("Volume `#{disk_id}' not found. Skipping.")
        end
      end
    end

    ##
    # Attaches an CloudStack volume to an OpenStack server
    #
    # @param [String] server_id CloudStack server UUID
    # @param [String] disk_id CloudStack volume UUID
    # @return [void]
    def attach_disk(server_id, disk_id)
      with_thread_name("attach_disk(#{server_id}, #{disk_id})") do
        server = @cloudstack.servers.get(server_id)
        unless server
          cloud_error("Server `#{server_id}' not found")
        end
        volume = @cloudstack.volumes.get(disk_id)
        unless server
          cloud_error("Volume `#{disk_id}' not found")
        end

        device_name = attach_volume(server, volume)

        update_agent_settings(server) do |settings|
          settings["disks"] ||= {}
          settings["disks"]["persistent"] ||= {}
          settings["disks"]["persistent"][disk_id] = device_name
        end
      end
    end

    ##
    # Detaches an OpenStack volume from an OpenStack server
    #
    # @param [String] server_id OpenStack server UUID
    # @param [String] disk_id OpenStack volume UUID
    # @return [void]
    def detach_disk(server_id, disk_id)
      with_thread_name("detach_disk(#{server_id}, #{disk_id})") do
        server = @openstack.servers.get(server_id)
        unless server
          cloud_error("Server `#{server_id}' not found")
        end
        volume = @openstack.volumes.get(disk_id)
        unless server
          cloud_error("Volume `#{disk_id}' not found")
        end

        detach_volume(server, volume)

        update_agent_settings(server) do |settings|
          settings["disks"] ||= {}
          settings["disks"]["persistent"] ||= {}
          settings["disks"]["persistent"].delete(disk_id)
        end
      end
    end

    ##
    # Validates the deployment
    #
    # @note Not implemented in the CloudStack CPI
    def validate_deployment(old_manifest, new_manifest)
      not_implemented(:validate_deployment)
    end

    private

    ##
    # Generates an unique name
    #
    # @return [String] Unique name
    def generate_unique_name
      UUIDTools::UUID.random_create.to_s
    end

    ##
    # Generates initial agent settings. These settings will be read by agent
    # from CloudStack registry (also a BOSH component) on a target server.
    # CloudStack volumes can be configured to map to other device names later
    # (vdc through vdz, also some kernels will remap vd* to xvd*).
    #
    # @param [String] server_name Name of the CloudStack server (will be picked
    #   up by agent to fetch registry settings)
    # @param [String] agent_id Agent id (will be picked up by agent to
    #   assume its identity
    # @param [Hash] network_spec Agent network spec
    # @param [Hash] environment Environment settings
    # @return [Hash] Agent settings
    def initial_agent_settings(server_name, vm_id, agent_id, network_spec, environment)
      settings = {
        "vm" => {
          "name" => server_name,
          "id" => vm_id
        },
        "agent_id" => agent_id,
        "networks" => network_spec,
      }

      settings["env"] = environment if environment
      settings.merge(@agent_properties)
    end

    ##
    # Updates the agent settings
    #
    # @param [Fog::Compute::CloudStack::Server] server CloudStack server
    def update_agent_settings(server)
      unless block_given?
        raise ArgumentError, "Block is not provided"
      end

      @logger.info("Updating settings for server `#{server.id}'...")
      settings = @registry.read_settings(server.name)
      yield settings
      @registry.update_settings(server.name, settings)
    end

    ##
    # Soft reboots an CloudStack server
    #
    # @param [Fog::Compute::CloudStack::Server] server CloudStack server
    # @return [void]
    def soft_reboot(server)
      @logger.info("Soft rebooting vm `#{vm.id}'...")
      vm.reboot
      wait_resource(server, :running, :state)
    end

    ##
    # Hard reboots an CouldStack server
    #
    # @param [Fog::Compute::CouldStack::Server] server CouldStack server
    # @return [void]
    def hard_reboot(server)
      @logger.info("Hard rebooting server `#{server.id}'...")
      server.reboot(type = 'HARD')
      wait_resource(server, :running, :state)
    end

    ##
    # Attaches an CloudStack volume to an CloudStack server
    #
    # @param [Fog::Compute::CloudStack::Server] server CloudStack server
    # @param [Fog::Compute::CloudStack::Volume] volume CloudStack volume
    # @return [String] Device name
    def attach_volume(server, volume)
      #get taken devices of this vm
      # volume_attachments = @cloudstack.get_server_volumes(server.id).
      #                      body['volumeAttachments']
      
      #device_names = Set.new(volume_attachments.collect! { |v| v["device"] })
      device_names = Set.new
      new_attachment = nil
      ("c".."z").each do |char|
        dev_name = "/dev/vd#{char}"
        if device_names.include?(dev_name)
          @logger.warn("`#{dev_name}' on `#{server.id}' is taken")
          next
        end
        @logger.info("Attaching volume `#{volume.id}' to `#{server.id}', " \
                     "device name is `#{dev_name}'")
        if volume.attach(server.id, dev_name)
          wait_resource(volume, :"in-use", :server_id)
          new_attachment = dev_name
        end
        break
      end

      if new_attachment.nil?
        cloud_error("Server has too many disks attached")
      end

      new_attachment
    end

    ##
    # Detaches an CloudStack volume from an OpenStack server
    #
    # @param [Fog::Compute::CloudStack::Server] server CloudStack server
    # @param [Fog::Compute::CloudStack::Volume] volume CloudStack volume
    # @return [void]
    def detach_volume(server, volume)
      # get 
      # volume_attachments = @cloudstack.get_server_volumes(server.id).
      #                      body['volumeAttachments']
      device_map = volume_attachments.collect! { |v| v["volumeId"] }

      unless device_map.include?(volume.id)
        cloud_error("Disk `#{volume.id}' is not attached to " \
                    "server `#{server.id}'")
      end

      @logger.info("Detaching volume `#{volume.id}' from `#{server.id}'...")
      volume.detach(server.id, volume.id)
      wait_resource(volume, :available)
    end

    ##
    # Checks if options passed to CPI are valid and can actually
    # be used to create all required data structures etc.
    #
    # @return [void]
    # @raise [ArgumentError] if options are not valid
    def validate_options
      unless @options.has_key?("cloudstack") &&
          @options["cloudstack"].is_a?(Hash) &&
          @options["cloudstack"]["cloudstack_host"] &&
          @options["cloudstack"]["cloudstack_port"] &&
          @options["cloudstack"]["cloudstack_secret_access_key"] &&
          @options["cloudstack"]["cloudstack_scheme"]
        raise ArgumentError, "Invalid CloudStack configuration parameters"
      end

      unless @options.has_key?("registry") &&
          @options["registry"].is_a?(Hash) &&
          @options["registry"]["endpoint"] &&
          @options["registry"]["user"] &&
          @options["registry"]["password"]
        raise ArgumentError, "Invalid registry configuration parameters"
      end
    end
    
    def get_templates
       response = @cloudstack.list_templates({
          :templateFilter => "excutable"
        })
       if response
         response['listtemplatesresponse']['template']
       end
    end

    def task_checkpoint
      Bosh::Clouds::Config.task_checkpoint
    end

  end
end
