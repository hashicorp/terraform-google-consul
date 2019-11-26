<!--
:type: service
:name: HashiCorp Consul
:icon: /_docs/consul.png
:description: Deploy a Consul cluster. Supports automatic bootstrapping, DNS, Consul UI, and auto healing.
:category: Service discovery, service mesh
:cloud: google
:tags: consul, iam
:license: gruntwork
:built-with: terraform
-->

[![Maintained by Gruntwork.io](https://img.shields.io/badge/maintained%20by-gruntwork.io-%235849a6.svg)](https://gruntwork.io/?ref=repo_gcp_consul)
![Terraform Version](https://img.shields.io/badge/tf-%3E%3D0.12.0-blue.svg)
# Consul for Google Cloud Platform (GCP)

This repo contains a Terraform Module for how to deploy a [Consul](https://www.consul.io/) cluster on
[GCP](https://cloud.google.com/) using [Terraform](https://www.terraform.io/). Consul is a distributed, highly-available
tool that you can use for service discovery and key/value storage. A Consul cluster typically includes a small number
of server nodes, which are responsible for being part of the [consensus quorum](https://www.consul.io/docs/internals/consensus.html), and a larger number of client nodes, which you typically run alongside your apps:

![Terraform Google  Consul](https://raw.githubusercontent.com/hashicorp/terraform-google-consul/master/_docs/architecture.png)


## Features
* Secure service communication and observe communication between your services without modifying their code.
* Automate load balancer.
* Provides any number of health checks.
* Multi-Data centers out of the box.



## Learn

This repo is maintained by [Gruntwork](https://www.gruntwork.io), and follows the same patterns as [the Gruntwork Infrastructure as Code Library](https://gruntwork.io/infrastructure-as-code-library/), a collection of reusable, battle-tested, production ready infrastructure code. You can read [How to use the Gruntwork Infrastructure as Code Library](https://gruntwork.io/guides/foundations/how-to-use-gruntwork-infrastructure-as-code-library/) for an overview of how to use modules maintained by Gruntwork!

## Core concepts

* Consul Use Cases: overview of various use cases that consul is optimized for.
  * [Service Discovery](https://www.consul.io/discovery.html)

  * [Service Mesh](https://www.consul.io/mesh.html)

* [Consul Guides](https://learn.hashicorp.com/consul?utm_source=consul.io&utm_medium=docs&utm_content=top-nav): official guide on how to use Consul service to discover services and secure network traffic.

## Repo organization

* [modules](https://github.com/hashicorp/terraform-google-consul/tree/master/modules): the main implementation code for this repo, broken down into multiple standalone, orthogonal submodules.
* [examples](https://github.com/hashicorp/terraform-google-consul/tree/master/examples): This folder shows examples of different ways to combine the modules in the `modules` folder to deploy Consul.
* [test](https://github.com/hashicorp/terraform-google-consul/tree/master/test): Automated tests for the modules and examples.
* [root](https://github.com/hashicorp/terraform-google-consul/tree/master): The root folder is *an example* of how to use the [consul-cluster module](https://github.com/hashicorp/terraform-google-consul/tree/master/modules/consul-cluster) module to deploy a [Consul](https://www.consul.io/) cluster in [GCP](https://cloud.google.com/). The Terraform Registry requires the root of every repo to contain Terraform code, so we've put one of the examples there. This example is great for learning and experimenting, but for production use, please use the underlying modules in the [modules folder](https://github.com/hashicorp/terraform-google-consul/tree/master/modules) directly.


## Deploy

### Non-production deployment (quick start for learning)
If you just want to try this repo out for experimenting and learning, check out the following resources:

* [examples folder](https://github.com/hashicorp/terraform-google-consul/tree/master/examples): The `examples` folder contains sample code optimized for learning, experimenting, and testing (but not production usage).

### Production deployment

#### To deploy Consul servers for production using this repo:

1. Create a Consul Image using a Packer template that references the [install-consul module](https://github.com/hashicorp/terraform-google-consul/tree/master/modules/install-consul).
   Here is an [example Packer template](https://github.com/hashicorp/terraform-google-consul/tree/master/examples/consul-image#quick-start). 
   Note that Google Cloud does not support custom
   public Images so you must build this Packer template on your own to proceed.

   
2. Deploy that Image across a Compute Instance Group using the Terraform [consul-cluster module](https://github.com/hashicorp/terraform-google-consul/tree/master/modules/consul-cluster)
   and execute the [run-consul script](https://github.com/hashicorp/terraform-google-consul/tree/master/modules/run-consul) with the `--server` flag during boot on each 
   Instance in the Compute Instance Group to form the Consul cluster. Here is an example [Terraform configuration](https://github.com/hashicorp/terraform-google-consul/tree/master/examples/root-example#quick-start) to provision a Consul cluster.

#### To deploy Consul clients for production using this repo:
 
1. Use the [install-consul module](https://github.com/hashicorp/terraform-google-consul/tree/master/modules/install-consul) to install Consul alongside your application code.
1. Before booting your app, execute the [run-consul script](https://github.com/hashicorp/terraform-google-consul/tree/master/modules/run-consul) with `--client` flag.
1. Your app can now use the local Consul agent for service discovery and key/value storage.
1. Optionally, you can use the [install-dnsmasq module](https://github.com/hashicorp/terraform-google-consul/tree/master/modules/install-dnsmasq) to configure Consul as the DNS for a
   specific domain (e.g. `.consul`) so that URLs such as `foo.service.consul` resolve automatically to the IP
   address(es) for a service `foo` registered in Consul (all other domain names will be continue to resolve using the
   default resolver on the OS).

## Support
If you need help with this repo or anything else related to infrastructure or DevOps, Gruntwork offers [Commercial Support](https://gruntwork.io/support/) via Slack, email, and phone/video. If you're already a Gruntwork customer, hop on Slack and ask away! If not, [subscribe now](https://www.gruntwork.io/pricing/). If you're not sure, feel free to email us at [support@gruntwork.io](mailto:support@gruntwork.io).


## How do I contribute to this Module?

Contributions are very welcome! Check out the [Contribution Guidelines](https://github.com/hashicorp/terraform-google-consul/tree/master/CONTRIBUTING.md) for instructions.


## License

Please see [LICENSE](LICENSE) for details on how the code in this repo is licensed.
