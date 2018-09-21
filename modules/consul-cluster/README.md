# Consul Cluster

This folder contains a [Terraform](https://www.terraform.io/) module to deploy a 
[Consul](https://www.consul.io/) cluster in [GCP](https://cloud.google.com/) on top of a Zonal Manged Instance
Group. This module is designed to deploy a [Google Image](https://cloud.google.com/compute/docs/images) that has Consul
installed via the [install-consul](https://github.com/hashicorp/terraform-google-consul/tree/master/modules/install-consul) module in this Module.



## How do you use this module?

This folder defines a [Terraform module](https://www.terraform.io/docs/modules/usage.html), which you can use in your
code by adding a `module` configuration and setting its `source` parameter to URL of this folder:

```hcl
module "consul_cluster" {
  # Use version v0.0.1 of the consul-cluster module
  source = "github.com/gruntwork-io/consul-gcp-module//modules/consul-cluster?ref=v0.0.1"

  # Specify either the Google Image "family" or a specific Google Image. You should build this using the scripts
  # in the install-consul module.
  source_image = "consul"
  
  # Add this tag to each node in the cluster
  cluster_tag_name = "consul-cluster-example"
  
  # Configure and start Consul during boot. It will automatically form a cluster with all nodes that have that
  # same tag. 
  startup_script = <<-EOF
              #!/bin/bash
              /opt/consul/bin/run-consul --server --cluster-tag-name consul-cluster
              EOF
  
  # ... See variables.tf for the other parameters you must define for the consul-cluster module
}
```

Note the following parameters:

* `source`: Use this parameter to specify the URL of the consul-cluster module. The double slash (`//`) is intentional 
  and required. Terraform uses it to specify subfolders within a Git repo (see [module 
  sources](https://www.terraform.io/docs/modules/sources.html)). The `ref` parameter specifies a specific Git tag in 
  this repo. That way, instead of using the latest version of this module from the `master` branch, which 
  will change every time you run Terraform, you're using a fixed version of the repo.

* `source_image`: Use this parameter to specify the name of the Consul [Google Image](https://cloud.google.com/compute/docs/images)
  to deploy on each server in the cluster. You should install Consul in this Image using the scripts in the 
  [install-consul](https://github.com/hashicorp/terraform-google-consul/tree/master/modules/install-consul) module.
  
* `startup_script`: Use this parameter to specify a [Startup Script](https://cloud.google.com/compute/docs/startupscript) script that each
  server will run during boot. This is where you can use the [run-consul script](https://github.com/hashicorp/terraform-google-consul/tree/master/modules/run-consul) to configure and 
  run Consul. The `run-consul` script is one of the scripts installed by the [install-consul](https://github.com/hashicorp/terraform-google-consul/tree/master/modules/install-consul) 
  module. 

You can find the other parameters in [variables.tf](variables.tf).

Check out the [consul-cluster example](https://github.com/hashicorp/terraform-google-consul/tree/master/examples/root-example) for fully-working sample code.




## How do you connect to the Consul cluster?

### Using the HTTP API from your own computer

If you want to connect to the cluster from your own computer, the easiest way is to use the [HTTP 
API](https://www.consul.io/docs/agent/http.html). Note that this only works if the Consul cluster is running with 
`assign_public_ip_addresses` set to `true` (as in the [consul-cluster example](https://github.com/hashicorp/terraform-google-consul/tree/master/examples/root-example)), which is OK
for testing and experimentation, but NOT recommended for production usage.

To use the HTTP API, you first need to get the public IP address of one of the Consul Servers. You can find Consul 
servers by using Compute Instance tags. If you're running the [consul-cluster example](https://github.com/hashicorp/terraform-google-consul/tree/master/examples/root-example), the
[consul-examples-helper.sh script](https://github.com/hashicorp/terraform-google-consul/tree/master/examples/consul-examples-helper/consul-examples-helper.sh) will do the tag lookup 
for you automatically (note, you must have the [Google Cloud SDK](https://cloud.google.com/sdk/) and the 
[Consul agent](https://www.consul.io/) installed locally):

```
> ../consul-examples-helper/consul-examples-helper.sh

Your Consul servers are running at the following IP addresses:

34.200.218.123
34.205.127.138
34.201.165.11
```

You can use one of these IP addresses with the `members` command to see a list of cluster nodes:

```
> consul members -http-addr=11.22.33.44:8500

Node                Address          Status  Type    Build  Protocol  DC
consul-client-5xb8  10.138.0.3:8301  alive   client  0.9.2  2         us-west1-a
consul-client-m1bz  10.138.0.8:8301  alive   client  0.9.2  2         us-west1-a
consul-client-xlbb  10.138.0.2:8301  alive   client  0.9.2  2         us-west1-a
consul-server-45c2  10.138.0.4:8301  alive   server  0.9.2  2         us-west1-a
consul-server-bm7t  10.138.0.7:8301  alive   server  0.9.2  2         us-west1-a
consul-server-ntcp  10.138.0.6:8301  alive   server  0.9.2  2         us-west1-a
```

You can also try inserting a value:

```
> consul kv put -http-addr=11.22.33.44:8500 foo bar

Success! Data written to: foo
```

And reading that value back:
 
```
> consul kv get -http-addr=11.22.33.44:8500 foo

bar
```

Finally, you can try opening up the Consul UI in your browser at the URL `http://11.22.33.44:8500/ui/`.

![Consul UI](https://github.com/hashicorp/terraform-google-consul/blob/master/_docs/consul-ui-screenshot.png?raw=true)


### Using the Consul agent on another Compute Instance

The easiest way to run [Consul agent](https://www.consul.io/docs/agent/basics.html) and have it connect to the Consul 
Server cluster is to note the [tag](https://cloud.google.com/compute/docs/vpc/add-remove-network-tags) used by a Compute
Instance where the Consul agent is running, and specify it in the `allowed_inbound_tags_http_api` property of the 
`consul-cluster` module. To grant DNS access, you can specify the same tag in the `allowed_inbound_tags_dns`
property of the `consul-cluster` module.

For example, imagine you deployed a Consul Server cluster as follows:

```hcl
module "consul_server_cluster" {
  source = "github.com/hashicorp/terraform-google-consul//modules/consul-cluster?ref=v0.0.1

  # Add this tag to each node in the cluster
  allowed_inbound_tags_http_api = "consul-client-example"
  allowed_inbound_tags_dns = "consul-client-example"
  
  # ... Other params omitted ... 
}
```

Using the `retry-join` params, you can run a Consul agent on a Compute Instance as follows: 

```
consul agent -retry-join 'provider=gce project_name=my-project tag_value=consul-server' -data-dir=/tmp/consul
```

Note that, by default, the Consul cluster nodes advertise their *private* IP addresses, so the command above only works
from Compute Instances inside the same VPC Network (or any VPC network with proper peering connections and route table
entries).




## What's included in this module?

This module creates the following architecture:

![Consul architecture](https://github.com/hashicorp/terraform-google-consul/blob/master/_docs/architecture.png?raw=true)

This architecture consists of the following resources:

* [Zonal Managed Instance Group](#zonal-managed-instance-group)
* [Firewall Rules](#firewall-rules)


### Regional Managed Instance Group

This module runs Consul on top of a [Regional Managed Instance Group](https://cloud.google.com/compute/docs/instance-groups/)
, which spreads Compute Instances across multiple [Zones](
https://cloud.google.com/compute/docs/regions-zones/regions-zones) for High Availability.

Each of the Compute Instances should be running a Google Image that has Consul installed via the [install-consul](https://github.com/hashicorp/terraform-google-consul/tree/master/modules/install-consul)
module. You pass in the name of the Image to run using the `source_image` input parameter.

#### Compute Instance Tags

This module allows you to specify a [tag](https://cloud.google.com/compute/docs/vpc/add-remove-network-tags) to add to
each Compute Instance in the Managed Instance Group. We recommend using this tag with the [retry_join](
https://www.consul.io/docs/agent/options.html?#retry-join) configuration to allow the Compute Instances to find each
other and automatically form a cluster.


### Firewall Rules

We create separate Firewall Rules that allow:
 
* All the inbound ports specified in the [Consul documentation](https://www.consul.io/docs/agent/options.html?#ports-used)
  for use within the Consul Cluster.
* HTTP API requests from GCP resources that have the given tags or any IP address within the given CIDR Blocks
* DNS requests from GCP resources that have the given tags or any IP address within the given CIDR Blocks


## How do you roll out updates?

Unfortunately, this remains an open item. Unlike Amazon Web Services, Google Cloud does not allow you to control the
manner in which Compute Instances in a Managed Instance Group are updated, except that you can specify that either
all Instances should be immediately restarted when a Managed Instance Group's Instance Template is updated (by setting
the [update_strategy](https://www.terraform.io/docs/providers/google/r/compute_instance_group_manager.html#update_strategy)
of the Managed Instance Group to `RESTART`), or that nothing at all should happen (by setting the update_strategy to 
`NONE`).

While updating Consul, we must be mindful of always preserving a [quorum](https://www.consul.io/docs/guides/servers.html#removing-servers),
but neither of the above options enables a safe update.

One possible option may be the use of GCP's [Rolling Updates Feature](https://cloud.google.com/compute/docs/instance-groups/updating-managed-instance-groups)
however this feature remains in Alpha and may not necessarily support our use case.

The most likely solution will involve writing a script that makes use of the [abandon-instances](https://cloud.google.com/sdk/gcloud/reference/compute/instance-groups/managed/abandon-instances)
and [resize](https://cloud.google.com/sdk/gcloud/reference/compute/instance-groups/managed/resize) GCP API calls. Using
these primitives, we can "abandon" Compute Instances from a Compute Instance Group (thereby removing them from the Group
but leaving them otherwise untouched), manually add new Instances based on an updated Instance Template that will 
automatically join the Consul cluster, make Consul API calls to our abandoned Instances to leave the Group, validate
that all new Instances are members of the cluster and then manually terminate the abandoned Instances.  

Needless to say, PRs are welcome!

## What happens if a node crashes?

There are two ways a Consul node may go down:
 
1. The Consul process may crash. In that case, `supervisor` should restart it automatically.
1. The Compute Instance running Consul stops, crashes, or is otherwise deleted. In that case, the Managed Instance Group
   will launch a replacement automatically.  Note that in this case, although the Consul agent did not exit gracefully,
   the replacement Instance will have the same name and therefore no manual clean out of old nodes is necessary!

## Gotchas

We strongly recommend that you set `assign_public_ip_addresses` to `false` so that your Consul nodes are NOT addressable
from the public Internet. But running private nodes creates a few gotchas:

- **Configure Private Google Access.** By default, the Google Cloud API is queried over the public Internet, but private
  Compute Instances have no access to the public Internet so how do they query the Google API? Fortunately, Google 
  enables a Subnet property where you can [access Google APIs from within the network](
  https://cloud.google.com/compute/docs/private-google-access/configure-private-google-access) and not over the public
  Internet. **Setting this property is outside the scope of this module, but private Vault servers will not work unless
  this is enabled, or they have public Internet access.**

- **SSHing to private Compute Instances.** When a Compute Instance is private, you can only SSH into it from within the
  network. This module does not give you any direct way to SSH to the private Compute Instances, so you must separately
  setup a means to enter the network, for example, by setting up a public Bastion Host.

- **Internet access for private Compute Instances.** If you do want your private Compute Instances to have Internet 
  access, then Google recommends [setting up your own network proxy or NAT Gateway](
  https://cloud.google.com/compute/docs/vpc/special-configurations#proxyvm).  

## Security

Here are some of the main security considerations to keep in mind when using this module:

1. [Encryption in transit](#encryption-in-transit)
1. [Encryption at rest](#encryption-at-rest)
1. [Firewall rules](#firewall-rules)
1. [SSH access](#ssh-access)


### Encryption in transit

Consul can encrypt all of its network traffic. For instructions on enabling network encryption, have a look at the
[How do you handle encryption documentation](https://github.com/hashicorp/terraform-google-consul/tree/master/modules/run-consul#how-do-you-handle-encryption).


### Encryption at rest

The Compute Instances in the cluster store all their data on the root disk volume. By default, [GCE encrypts all data at
rest](https://cloud.google.com/compute/docs/disks/customer-supplied-encryption), a process managed by GCE without any 
additional actions needed on your part. You can also provide your own encryption keys and GCE will use these to protect
the Google-generated keys used to encrypt and decrypt your data.  


### Firewall rules

This module creates Firewall rules that allow inbound requests as follows:

* **Consul**: For all the [ports used by Consul](https://www.consul.io/docs/agent/options.html#ports), all members of 
  the Consul Server cluster will automatically accept inbound traffic based on a [tag](
  https://cloud.google.com/compute/docs/vpc/add-remove-network-tags) shared by all cluster members.  

* **External HTTP API Access**: For external access to the Consul Server cluster over the HTTP API port (default: 8500),
  you can use the `allowed_inbound_cidr_blocks_http_api` parameter to control the list of [CIDR blocks](
  https://en.wikipedia.org/wiki/Classless_Inter-Domain_Routing), and the `allowed_inbound_tags_http_api` to control the
  list of tags that will be allowed access.
  
* **External DNS Access**: For external access to the Consul Server cluster via the DNS port (default: 8600),
  you can use the `allowed_inbound_cidr_blocks_dns` parameter to control the list of CIDR blocks, and the 
  `allowed_inbound_tags_dns` to control the list of tags that will be allowed access. 
  
Note that all the ports mentioned above are configurable via the `xxx_port` variables (e.g. `server_rpc_port`). See
[variables.tf](variables.tf) for the full list.
  
  

### SSH access

You can SSH to the Compute Instances using the [conventional methods offered by GCE](
https://cloud.google.com/compute/docs/instances/connecting-to-instance). Google [strongly recommends](
https://cloud.google.com/compute/docs/instances/adding-removing-ssh-keys) that you connect to an Instance [from your web
browser](https://cloud.google.com/compute/docs/instances/connecting-to-instance#sshinbrowser) or using the [gcloud
command line tool](https://cloud.google.com/compute/docs/instances/connecting-to-instance#sshingcloud).

If you must manually manage your SSH keys, use the `custom_metadata` property to specify accepted SSH keys in the format
required by GCE. 



## What's NOT included in this module?

This module does NOT handle the following items, which you may want to provide on your own:

* [Monitoring, alerting, log aggregation](#monitoring-alerting-log-aggregation)
* [VPCs, subnetworks, route tables](#vpcs-subnetworks-route-tables)
* [DNS entries](#dns-entries)


### Monitoring, alerting, log aggregation

This module does not include anything for monitoring, alerting, or log aggregation. All Compute Instance Groups and 
Compute Instances come with the option to use [Google StackDriver](https://cloud.google.com/stackdriver/), GCP's monitoring,
logging, and diagnostics platform that works with both GCP and AWS.

If you wish to install the StackDriver monitoring agent or logging agent, pass the desired installation instructions to
the `startup_script` property.


### VPCs, subnetworks, route tables

This module assumes you've already created your network topology (VPC, subnetworks, route tables, etc). By default,
it will use the "default" network for the Project you select, but you may specify custom networks via the `network_name`
and `subnetwork_name` properties.


### DNS entries

This module does not create any DNS entries for Consul (e.g. with Cloud DNS).
