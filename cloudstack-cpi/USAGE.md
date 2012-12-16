# BOSH CloudStack Cloud Provider Interface
# Copyright (c) 2012 Tongtech, Inc.


## Options

These options are passed to the CloudStack CPI when it is instantiated.

### CloudStack options

* `cloudstack_host` (required)
  Host of the CloudStack Manager server endpoint to connect to
* `cloudstack_port` (required)
  Port of the CloudStack Manager server endpoint to connect to
* `cloudstack_api_key` (required)
  CloudStack API key
* `cloudstack_secret_access_key` (required)
  CloudStack secret access key due to access API
* `cloudstack_scheme` (optional)
  CloudStack Manager server http/https model. Default is https 
* `default_key_name` (required)
  default CloudStack ssh key name to assign to created virtual machines
* `default_security_groups` (optional)
  default CloudStack security group to assign to created virtual machines


### Registry options

The registry options are passed to the CloudStack CPI by the BOSH director based on the settings in `director.yml`, but can be overridden if needed.

* `endpoint` (required)
  CloudStack registry URL
* `user` (required)
  CloudStack registry user
* `password` (required)
  rCloudStack egistry password

### Agent options

Agent options are passed to the CloudStack  CPI by the BOSH director based on the settings in `director.yml`, but can be overridden if needed.

### Resource pool options

These options are specified under `cloud_options` in the `resource_pools` section of a BOSH deployment manifest.

* `instance_type` (required)
  which type of instance (CloudStack flavor Medium Instance|Small Instance) the VMs should belong to


### Network options

These options are specified under `cloud_options` in the `networks` section of a BOSH deployment manifest.

* `type` (required)
  can be either `dynamic` for a DHCP assigned IP by CloudStack, or `vip` to use a Floating IP (which needs to be already allocated)

## Example

This is a sample of how CloudStack specific properties are used in a BOSH deployment manifest:

    ---
    name: sample
    director_uuid: 38ce80c3-e9e9-4aac-ba61-97c676631b91

    ...

    networks:
      - name: nginx_network
        type: vip
        cloud_properties: {}
      - name: default
        type: dynamic
        cloud_properties:
          security_groups:
          - default

    ...

    resource_pools:
      - name: common
        network: default
        size: 3
        stemcell:
          name: bosh-stemcell
          version: 0.0.
        cloud_properties:
          instance_type: "Medium Instance"

    ...

    properties:
      cloudstack:
        cloudstack_host: 168.1.43.14
        cloudstack_port: 8080
        cloudstack_api_key: hHdIgGdz6V-6I9Dc0dqhgUKutGJX-7_XTurvjd89SWAXPFiMZEy_Gb0uGfzbTyzS1rrdcwwZq81nxWS3UW8IcQ
        cloudstack_secret_access_key: zKao312dFgDKFdSI04Kh2axSuiWDXLDXj848GFxXRvRZPjiEuA6UfQq4uGdEHxrvuaYoNpv3_SBWfRqX6lPIwg
        cloudstack_scheme: http
        default_security_groups: ["default"]