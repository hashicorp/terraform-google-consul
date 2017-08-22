# Consul Terraform Module for Google Cloud Platform (GCP)

This repo contains a Terraform Module for how to deploy a [Consul](https://www.consul.io/) cluster on 
[GCP](https://cloud.google.com/) using [Terraform](https://www.terraform.io/). Consul is a distributed, highly-available 
tool that you can use for service discovery and key/value storage. A Consul cluster typically includes a small number
of server nodes, which are responsible for being part of the [consensus 
quorum](https://www.consul.io/docs/internals/consensus.html), and a larger number of client nodes, which you typically 
run alongside your apps:

![Consul architecture](/_docs/architecture.png)



## How to use this Module

Each Module has the following folder structure:

* [modules](/modules): This folder contains the reusable code for this Module, broken down into one or more submodules.
* [examples](/examples): This folder contains examples of how to use the submodules.
* [test](/test): Automated tests for the submodules and examples.

To deploy Consul servers using this Module:

1. Create a Consul Image using a Packer template that references the [install-consul module](/modules/install-consul).
   Here is an [example Packer template](/examples/consul-image#quick-start). Note that Google Cloud does not support custom
   public Images so you must build this Packer template on your own to proceed.
   
1. Deploy that Image across a Compute Instance Group using the Terraform [consul-cluster module](/modules/consul-cluster) 
   and execute the [run-consul script](/modules/run-consul) with the `--server` flag during boot on each 
   Instance in the Compute Instance Group to form the Consul cluster. Here is [an example Terraform 
   configuration](/examples/consul-cluster#quick-start) to provision a Consul cluster.

To deploy Consul clients using this Module:
 
1. Use the [install-consul module](/modules/install-consul) to install Consul alongside your application code.
1. Before booting your app, execute the [run-consul script](/modules/run-consul) with `--client` flag.
1. Your app can now usr the local Consul agent for service discovery and key/value storage. 
1. Optionally, you can use the [install-dnsmasq module](/modules/install-dnsmasq) to configure Consul as the DNS for a
   specific domain (e.g. `.consul`) so that URLs such as `foo.service.consul` resolve automatically to the IP 
   address(es) for a service `foo` registered in Consul (all other domain names will be continue to resolve using the
   default resolver on the OS).
   
 


## What's a Terraform Module?

A Terraform Module is a canonical, reusable, best-practices definition for how to run a single piece of infrastructure, 
such as a database or server cluster. Each Terraform Module is created using [Terraform](https://www.terraform.io/), and
includes automated tests, examples, and documentation. It is maintained both by the open source community and 
companies that provide commercial support. 

Instead of figuring out the details of how to run a piece of infrastructure from scratch, you can reuse 
existing code that has been proven in production. And instead of maintaining all that infrastructure code yourself, 
you can leverage the work of the Terraform Module community to pick up infrastructure improvements through
a version number bump.
 
 
 
## Who maintains this Terraform Module?

This Terraform Module is maintained by [Gruntwork](http://www.gruntwork.io/). If you're looking for help or commercial 
support, send an email to [modules@gruntwork.io](mailto:modules@gruntwork.io?Subject=Consul%20Terraform%20Module). 
Gruntwork can help with:

* Setup, customization, and support for this Terraform Module.
* Terraform Module for other types of Google Cloud infrastructure.
* Terraform Modules that meet compliance requirements, such as HIPAA.
* Consulting & Training on Google Cloud, AWS, Terraform, and DevOps.



## Code included in this Terraform Module:

* [install-consul](/modules/install-consul): This module installs Consul using a
  [Packer](https://www.packer.io/) template to create a Consul 
  [Custom Image](https://cloud.google.com/compute/docs/images).

* [consul-cluster](/modules/consul-cluster): The module includes Terraform code to deploy a Consul Image across a [Managed
  Compute Instance Group](https://cloud.google.com/compute/docs/instance-groups/). 
  
* [run-consul](/modules/run-consul): This module includes the scripts to configure and run Consul. It is used
  by the above Packer module at build-time to set configurations, and by the Terraform module at runtime 
  with the Instance's [Startup Script](https://cloud.google.com/compute/docs/startupscript) to create the cluster.

* [install-dnsmasq module](/modules/install-dnsmasq): Install [Dnsmasq](http://www.thekelleys.org.uk/dnsmasq/doc.html)
  and configure it to forward requests for a specific domain to Consul. This allows you to use Consul as a DNS server
  for URLs such as `foo.service.consul`.

* [consul-external-regional-load-balancer](/modules/consul-external-regional-load-balancer): This module creates a 
  public-facing Load Balancer that fronts the Consul Server cluster. This is useful for testing purposes only. In production,
  your Consul cluster should only be accessible from within your network. 

## How do I contribute to this Terraform Module?

Contributions are very welcome! Check out the [Contribution Guidelines](/CONTRIBUTING.md) for instructions.



## How is this Terraform Module versioned?

This Terraform Module follows the principles of [Semantic Versioning](http://semver.org/). You can find each new release, 
along with the changelog, in the [Releases Page](../../releases). 

During initial development, the major version will be 0 (e.g., `0.x.y`), which indicates the code does not yet have a 
stable API. Once we hit `1.0.0`, we will make every effort to maintain a backwards compatible API and use the MAJOR, 
MINOR, and PATCH versions on each release to indicate any incompatibilities. 



## License

This code is released under the Apache 2.0 License. Please see [LICENSE](/LICENSE) and [NOTICE](/NOTICE) for more 
details.

