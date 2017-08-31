# Consul Google Image

This folder shows an example of how to use the [install-consul](https://github.com/gruntwork-io/terraform-google-consul/modules/install-consul) and 
[install-dnsmasq](https://github.com/gruntwork-io/terraform-google-consul/modules/install-dnsmasq) modules with [Packer](https://www.packer.io/) to create [Custom Images](
https://cloud.google.com/compute/docs/images) that have Consul and Dnsmasq installed on 
top of Ubuntu 16.04 LTS. At this time, Ubuntu 16.04 LTS is the only supported Linux distribution.

These Images will have [Consul](https://www.consul.io/) installed and configured to automatically join a cluster during 
boot-up. They also have [Dnsmasq](http://www.thekelleys.org.uk/dnsmasq/doc.html) installed and configured to use 
Consul for DNS lookups of the `.consul` domain (e.g. `foo.service.consul`) (see [registering 
services](https://www.consul.io/intro/getting-started/services.html) for instructions on how to register your services
in Consul). To see how to deploy this Image, check out the [consul-cluster example](https://github.com/gruntwork-io/terraform-google-consul/examples/consul-cluster). 

For more info on Consul installation and configuration, check out the 
[install-consul](https://github.com/gruntwork-io/terraform-google-consul/modules/install-consul) and [install-dnsmasq](https://github.com/gruntwork-io/terraform-google-consul/modules/install-dnsmasq) documentation.



## Quick start

To build the Consul Image:

1. `git clone` this repo to your computer.
1. Install [Packer](https://www.packer.io/).
1. Configure your environment's Google credentials using the [Google Cloud SDK](https://cloud.google.com/sdk/).
1. Update the `variables` section of the `consul.json` Packer template to configure the Project ID, Google Cloud Zone, 
   and Consul version you wish to use.
1. Run `packer build consul.json`.

When the build finishes, it will output the ID of the new Custom Image. To see how to deploy one of these Images, check
out the  [consul-cluster example](https://github.com/gruntwork-io/terraform-google-consul/examples/consul-cluster).




## Creating your own Packer template for production usage

When creating your own Packer template for production usage, you can copy the example in this folder more or less 
exactly, except for one change: we recommend replacing the `file` provisioner with a call to `git clone` in the `shell` 
provisioner. Instead of:

```json
{
  "provisioners": [{
    "type": "file",
    "source": "{{template_dir}}/../../../consul-gcp-module",
    "destination": "/tmp"
  },{
    "type": "shell",
    "inline": [
      "/tmp/consul-gcp-module/modules/install-consul/install-consul --version {{user `consul_version`}}",
      "/tmp/consul-gcp-module/modules/install-dnsmasq/install-dnsmasq"
    ],
    "pause_before": "30s"
  }]
}
```

Your code should look more like this:

```json
{
  "provisioners": [{
    "type": "shell",
    "inline": [
      "git clone --branch <MODULE_VERSION> https://github.com/gruntwork-io/consul-gcp-module.git /tmp/consul-gcp-module",
      "/tmp/consul-gcp-module/modules/install-consul/install-consul --version {{user `consul_version`}}",
      "/tmp/consul-gcp-module/modules/install-dnsmasq/install-dnsmasq"
    ],
    "pause_before": "30s"
  }]
}
```

You should replace `<MODULE_VERSION>` in the code above with the version of this Module that you want to use (see
the [Releases Page](https://github.com/gruntwork-io/terraform-google-consul/releases) for all available versions). That's because for production usage, you should always
use a fixed, known version of this Module, downloaded from the official Git repo. On the other hand, when you're 
just experimenting with the Module, it's OK to use a local checkout of the Module, uploaded from your own 
computer.