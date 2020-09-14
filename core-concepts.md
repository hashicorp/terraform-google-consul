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