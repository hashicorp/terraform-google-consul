# Consul Cluster

This folder contains a [Terraform](https://www.terraform.io/) module to deploy a 
[Consul](https://www.consul.io/) cluster in [GCP](https://cloud.google.com/) on top of a Zonal Manged Instance
Group. This module is designed to deploy a [Google Image](https://cloud.google.com/compute/docs/images) that has Consul
installed via the [install-consul](/modules/install-consul) module in this Module.



## How do you use this module?

This folder defines a [Terraform module](https://www.terraform.io/docs/modules/usage.html), which you can use in your
code by adding a `module` configuration and setting its `source` parameter to URL of this folder:

```hcl
module "consul_cluster" {
  # Use version v0.0.1 of the consul-cluster module
  source = "github.com/gruntwork-io/consul-gcp-module//modules/consul-cluster?ref=v0.0.1"

  # Specify either the Google Image "family" or a specific Google Image. You should build this using the scripts in the
  # install-consul module.
  source_image = "consul"
  
  # Add this tag to each node in the cluster
  cluster_tag_name = "consul-cluster-example"
  
  # Configure and start Consul during boot. It will automatically form a cluster with all nodes that have that same tag. 
  startup_script = <<-EOF
              #!/bin/bash
              /opt/consul/bin/run-consul --server --cluster-tag-key consul-cluster
              EOF
  
  # ... See vars.tf for the other parameters you must define for the consul-cluster module
}
```

Note the following parameters:

* `source`: Use this parameter to specify the URL of the consul-cluster module. The double slash (`//`) is intentional 
  and required. Terraform uses it to specify subfolders within a Git repo (see [module 
  sources](https://www.terraform.io/docs/modules/sources.html)). The `ref` parameter specifies a specific Git tag in 
  this repo. That way, instead of using the latest version of this module from the `master` branch, which 
  will change every time you run Terraform, you're using a fixed version of the repo.

* `source_image`: Use this parameter to specify the ID of a Consul [Google Image](https://cloud.google.com/compute/docs/images)
  to deploy on each server in the cluster. You should install Consul in this AMI using the scripts in the 
  [install-consul](/modules/install-consul) module.
  
* `startup_script`: Use this parameter to specify a [Startup Script](https://cloud.google.com/compute/docs/startupscript) script that each
  server will run during boot. This is where you can use the [run-consul script](/modules/run-consul) to configure and 
  run Consul. The `run-consul` script is one of the scripts installed by the [install-consul](/modules/install-consul) 
  module. 

You can find the other parameters in [vars.tf](vars.tf).

Check out the [consul-cluster example](/examples/consul-cluster) for fully-working sample code. 




## How do you connect to the Consul cluster?

### Using the HTTP API from your own computer

If you want to connect to the cluster from your own computer, the easiest way is to use the [HTTP 
API](https://www.consul.io/docs/agent/http.html). Note that this only works if the Consul cluster is running with 
`assign_public_ip_addresses` set to `true` (as in the [consul-cluster example](/examples/consul-cluster)), which is OK
for testing and experimentation, but NOT recommended for production usage.

To use the HTTP API, you first need to get the public IP address of one of the Consul Servers. You can find Consul 
servers by using Compute Instance tags. If you're running the [consul-cluster example](/examples/consul-cluster), the 
[consul-examples-helper.sh script](/examples/consul-examples-helper/consul-examples-helper.sh) will do the tag lookup 
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

![Consul UI](/_docs/consul-ui-screenshot.png)


### Using the Consul agent on another Compute Instance

The easiest way to run [Consul agent](https://www.consul.io/docs/agent/basics.html) and have it connect to the Consul 
cluster is to specify a tag used by the Computer Instance where the Consul agent is running in the `allowed_inbound_tags_http_api`
property of the `consul-cluster` module. To grant DNS access, you can do the same with the `in the `allowed_inbound_tags_dns`
property.

For example, imagine you deployed a Consul cluster as follows:

<!-- TODO: update this to the final URL -->

```hcl
module "consul_cluster" {
  source = "github.com/gruntwork-io/consul-gcp-module//modules/consul-cluster?ref=v0.0.1"

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

![Consul architecture](/_docs/architecture.png)

This architecture consists of the following resources:

* [Zonal Managed Instance Group](#zonal-managed-instance-group)
* [Firewall Rules](#firewall-rules)


### Zonal Managed Instance Group

This module runs Consul on top of a [Zonal Managed Instance Group](https://cloud.google.com/compute/docs/instance-groups/)
Typically, you should run the Instance Group with 3 or 5 Compute Instances spread across multiple [Zones](
https://cloud.google.com/compute/docs/regions-zones/regions-zones). Unfortunately, due to a [Terraform limitation](
https://github.com/terraform-providers/terraform-provider-google/issues/45), Managed Instance Groups can only be deployed
to a single Zone.


Each of the Compute Instances should be running a Google IMage that has Consul installed via the [install-consul](/modules/install-consul)
module. You pass in the name of the Image to run using the `source_image` input parameter.


### Firewall Rules

We create separate Firewall Rules that allow:
 
* All the inbound ports specified in the [Consul documentation](https://www.consul.io/docs/agent/options.html?#ports-used)
  for use within the Consul Cluster.
* HTTP API requests from the given tags or CIDR Blocks
* DNS requests from the given the tags or CIDR Blocks


## How do you roll out updates?

If you want to deploy a new version of Consul across the cluster, the best way to do that is to:

1. Ensure that `instance_group_update_strategy` is set to `NONE`. This means that when you set the `source_image` property
   to a new Google Image, Google won't actually update any of the Compute Instances.
1. Set the `source_image` property to the ID of the new Google Image.
1. Run `terraform apply`.

This updates the Instance Template used by the Managed Instance Group, so any new Instances in the Managed Instance Group
will have your new Image, but it does NOT actually deploy those new instances. To make that happen, you should do the following:

1. Issue an API call to one of the old Instances in the Instance Group to have it leave gracefully. E.g.:

    ```
    curl -X PUT <OLD_INSTANCE_IP>:8500/v1/agent/leave
    ```
    
1. Once the instance has left the cluster, terminate it:
 
    ```
    gcloud alpha compute instance-groups managed rolling-action start-update  consul-server-josh-ig --version template=consul-server-josh00502322d8f86fcd562d937f89
    ```

1. After a minute or two, the Instance Group should automatically launch a new Instance, with the new Image, to replace the old one.

1. Wait for the new Instance to boot and join the cluster.

1. Repeat these steps for each of the other old Instances in the ASG.
   
We will add a script in the future to automate this process (PRs are welcome!).




## What happens if a node crashes?

There are two ways a Consul node may go down:
 
1. The Consul process may crash. In that case, `supervisor` should restart it automatically.
1. The EC2 Instance running Consul dies. In that case, the Auto Scaling Group should launch a replacement automatically. 
   Note that in this case, since the Consul agent did not exit gracefully, and the replacement will have a different ID,
   you may have to manually clean out the old nodes using the [force-leave
   command](https://www.consul.io/docs/commands/force-leave.html). We may add a script to do this 
   automatically in the future. For more info, see the [Consul Outage 
   documentation](https://www.consul.io/docs/guides/outage.html).




## Security

Here are some of the main security considerations to keep in mind when using this module:

1. [Encryption in transit](#encryption-in-transit)
1. [Encryption at rest](#encryption-at-rest)
1. [Dedicated instances](#dedicated-instances)
1. [Security groups](#security-groups)
1. [SSH access](#ssh-access)


### Encryption in transit

Consul can encrypt all of its network traffic. For instructions on enabling network encryption, have a look at the
[How do you handle encryption documentation](/modules/run-consul#how-do-you-handle-encryption).


### Encryption at rest

The EC2 Instances in the cluster store all their data on the root EBS Volume. To enable encryption for the data at
rest, you must enable encryption in your Consul AMI. If you're creating the AMI using Packer (e.g. as shown in
the [consul-ami example](/examples/consul-ami)), you need to set the [encrypt_boot 
parameter](https://www.packer.io/docs/builders/amazon-ebs.html#encrypt_boot) to `true`.  


### Dedicated instances

If you wish to use dedicated instances, you can set the `tenancy` parameter to `"dedicated"` in this module. 


### Security groups

This module attaches a security group to each EC2 Instance that allows inbound requests as follows:

* **Consul**: For all the [ports used by Consul](https://www.consul.io/docs/agent/options.html#ports), you can 
  use the `allowed_inbound_cidr_blocks` parameter to control the list of 
  [CIDR blocks](https://en.wikipedia.org/wiki/Classless_Inter-Domain_Routing) that will be allowed access.  

* **SSH**: For the SSH port (default: 22), you can use the `allowed_ssh_cidr_blocks` parameter to control the list of   
  [CIDR blocks](https://en.wikipedia.org/wiki/Classless_Inter-Domain_Routing) that will be allowed access. 
  
Note that all the ports mentioned above are configurable via the `xxx_port` variables (e.g. `server_rpc_port`). See
[vars.tf](vars.tf) for the full list.  
  
  

### SSH access

You can associate an [EC2 Key Pair](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html) with each
of the EC2 Instances in this cluster by specifying the Key Pair's name in the `ssh_key_name` variable. If you don't
want to associate a Key Pair with these servers, set `ssh_key_name` to an empty string.





## What's NOT included in this module?

This module does NOT handle the following items, which you may want to provide on your own:

* [Monitoring, alerting, log aggregation](#monitoring-alerting-log-aggregation)
* [VPCs, subnets, route tables](#vpcs-subnets-route-tables)
* [DNS entries](#dns-entries)


### Monitoring, alerting, log aggregation

This module does not include anything for monitoring, alerting, or log aggregation. All ASGs and EC2 Instances come 
with limited [CloudWatch](https://aws.amazon.com/cloudwatch/) metrics built-in, but beyond that, you will have to 
provide your own solutions.


### VPCs, subnets, route tables

This module assumes you've already created your network topology (VPC, subnets, route tables, etc). You will need to 
pass in the the relevant info about your network topology (e.g. `vpc_id`, `subnet_ids`) as input variables to this 
module.


### DNS entries

This module does not create any DNS entries for Consul (e.g. in Route 53).


