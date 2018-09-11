# Consul Run Script

This folder contains a script for configuring and running Consul on a [GCP](https://cloud.google.com/) Compute Instance. 
This script has been tested on the following operating systems:

* Ubuntu 16.04

There is a good chance it will work on other flavors of Debian as well.




## Quick start

This script assumes you installed it, plus all of its dependencies (including Consul itself), using the [install-consul 
module](https://github.com/hashicorp/terraform-google-consul/tree/master/modules/install-consul). The default install path is `/opt/consul/bin`, so to start Consul in server mode, 
you run:

```
/opt/consul/bin/run-consul --server
```

To start Consul in client mode, you run:
 
```
/opt/consul/bin/run-consul --client
```

This will:

1. Generate a Consul configuration file called `default.json` in the Consul config dir (default: `/opt/consul/config`).
   See [Consul configuration](#consul-configuration) for details on what this configuration file will contain and how
   to override it with your own configuration.
   
1. Generate a [Supervisor](http://supervisord.org/) configuration file called `run-consul.conf` in the Supervisor
   config dir (default: `/etc/supervisor/conf.d`) with a command that will run Consul:  
   `consul agent -config-dir=/opt/consul/config -data-dir=/opt/consul/data`.

1. Tell Supervisor to load the new configuration file, thereby starting Consul.

We recommend using the `run-consul` command as part of the [Startup Script](https://cloud.google.com/compute/docs/startupscript),
so that it executes when the Compute Instance is first booting. After runing `run-consul` on that initial boot, the `supervisord`
configuration  will automatically restart Consul if it crashes or the Compute instance reboots.

See the [consul-cluster example](https://github.com/hashicorp/terraform-google-consul/tree/master/examples/root-example) for fully-working sample code.




## Command line Arguments

The `run-consul` script accepts the following arguments:

**Required:**

* `server` If set, run in server mode. Exactly one of `--server` or `--client` must be set.
* `client` If set, run in client mode. Exactly one of `--server` or `--client` must be set.

**Optional:**
 
* `cluster-tag-name` Automatically form a cluster with Instances that have the same value for this Compute Instance tag
  name.
* `raft-protocol` This controls the internal version of the Raft consensus protocol used for server communications. Must
  be set to 3 in order to gain access to Autopilot features, with the exception of `cleanup_dead_servers`. Default is 3.
* `config-dir` The path to the Consul config folder. Default is to take the absolute path of `../config`, 
  relative to the `run-consul` script itself.
* `data-dir` The path to the Consul config folder. Default is to take the absolute path of `../data`, 
  relative to the `run-consul` script itself.
* `log-dir` The path to the Consul log folder. Default is the absolute path of '../log', relative to this script.
* `bin-dir` The path to the folder with Consul binary. Default is the absolute path of the parent folder of this script."
* `user` The user to run Consul as. Default is to use the owner of `config-dir`.
* `skip-consul-config` If this flag is set, don't generate a Consul configuration file. This is useful if 
  you have a custom configuration file and don't want to use any of of the default settings from `run-consul`. 

Example:

```
/opt/consul/bin/run-consul --server --cluster-tag-name consul-server-prod 
```




## Consul configuration

`run-consul` generates a configuration file for Consul called `default.json` that tries to figure out reasonable 
defaults for a Consul cluster in GCP. Check out the [Consul Configuration Files 
documentation](https://www.consul.io/docs/agent/options.html#configuration-files) for what configuration settings are
available.
  
  
### Default configuration

`run-consul` sets the following configuration values by default:
  
* [advertise_addr](https://www.consul.io/docs/agent/options.html#advertise_addr): Set to the Compute Instance's private IP 
  address.

* [bind_addr](https://www.consul.io/docs/agent/options.html#bind_addr): Set to the Compute Instance's private IP address.

* [bootstrap_expect](https://www.consul.io/docs/agent/options.html#bootstrap_expect): If `--server` is set, 
  set this config based on the [Instance Metadata](https://cloud.google.com/compute/docs/storing-retrieving-metadata) tags: 
    * Set this config to the value of the `cluster-size` tag.     

* [client_addr](https://www.consul.io/docs/agent/options.html#client_addr): Set to 0.0.0.0 so you can access the client
  and UI endpoint on each Compute Instance from the outside.

* [datacenter](https://www.consul.io/docs/agent/options.html#datacenter): Set to the current Instance Region (e.g. 
  `us-west1`), as fetched from [Instance Metadata](https://cloud.google.com/compute/docs/storing-retrieving-metadata).

* [node_name](https://www.consul.io/docs/agent/options.html#node_name): Set to the instance name, as fetched from 
  [Instance Metadata](https://cloud.google.com/compute/docs/storing-retrieving-metadata). 
  

* [raft-protocol](https://www.consul.io/docs/agent/options.html#raft_protocol) Set to the value of `--raft-protocol`.


* [retry_join](https://www.consul.io/docs/agent/options.html#retry-join): Set the following keys for this setting:
    * [provider](https://www.consul.io/docs/agent/options.html#provider-2): Set to `gce` for Google Compute Engine.
    * [project_name](https://www.consul.io/docs/agent/options.html#project_name): Set to the name of the GCP Project where
      the Consul Servers are located.
    * [tag_value](https://www.consul.io/docs/agent/options.html#tag_value-2): Set to the value of the tag shared by all
      Consul Server nodes.
      
* [server](https://www.consul.io/docs/agent/options.html#server): Set to true if `--server` is set.

* [ui](https://www.consul.io/docs/agent/options.html#ui): Set to true to make the UI available.


### Overriding the configuration

To override the default configuration, simply put your own configuration file in the Consul config folder (default: 
`/opt/consul/config`), but with a name that comes later in the alphabet than `default.json` (e.g. 
`my-custom-config.json`). Consul will load all the `.json` configuration files in the config dir and 
[merge them together in alphabetical order](https://www.consul.io/docs/agent/options.html#_config_dir), so that 
settings in files that come later in the alphabet will override the earlier ones. 

For example, to override the default `retry_join` settings, you could create a file called `tags.json` with the
contents:

```json
{
  "retry_join": {
    "provider": "gce",
    "project_name": "my-project",
    "tag_value": "custom-value"
  }
}
```

If you want to override *all* the default settings, you can tell `run-consul` not to generate a default config file
at all using the `--skip-consul-config` flag:

```
/opt/consul/bin/run-consul --server --skip-consul-config
```


### Required permissions

The `run-consul` script assumes only that the Compute Instance can query its own metadata, a permission enabled by 
default on all Compute Instances.




## How do you handle encryption?

Consul can encrypt all of its network traffic (see the [encryption docs for 
details](https://www.consul.io/docs/agent/encryption.html)), but by default, encryption is not enabled in this 
Module. To enable encryption, you need to do the following:

1. [Gossip encryption: provide an encryption key](#gossip-encryption-provide-an-encryption-key)
1. [RPC encryption: provide TLS certificates](#rpc-encryption-provide-tls-certificates)


### Gossip encryption: provide an encryption key

To enable Gossip encryption, you need to provide a 16-byte, Base64-encoded encryption key, which you can generate using
the [consul keygen command](https://www.consul.io/docs/commands/keygen.html). You can put the key in a Consul 
configuration file (e.g. `encryption.json`) in the Consul config dir (default location: `/opt/consul/config`):

```json
{
  "encrypt": "cg8StVXbQJ0gPvMd9o7yrg=="
}
```


### RPC encryption: provide TLS certificates

To enable RPC encryption, you need to provide the paths to the CA and signing keys ([here is a tutorial on generating 
these keys](http://russellsimpkins.blogspot.com/2015/10/consul-adding-tls-using-self-signed.html)). You can specify 
these paths in a Consul configuration file (e.g. `encryption.json`) in the Consul config dir (default location: 
`/opt/consul/config`):

```json
{
  "ca_file": "/opt/consul/tls/certs/ca-bundle.crt",
  "cert_file": "/opt/consul/tls/certs/my.crt",
  "key_file": "/opt/consul/tls/private/my.key"
}
```

You will also want to set the [verify_incoming](https://www.consul.io/docs/agent/options.html#verify_incoming) and
[verify_outgoing](https://www.consul.io/docs/agent/options.html#verify_outgoing) settings to verify TLS certs on 
incoming and outgoing connections, respectively:

```json
{
  "ca_file": "/opt/consul/tls/certs/ca-bundle.crt",
  "cert_file": "/opt/consul/tls/certs/my.crt",
  "key_file": "/opt/consul/tls/private/my.key",
  "verify_incoming": true,
  "verify_outgoing": true
}
```



