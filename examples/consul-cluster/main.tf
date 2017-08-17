# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY A CONSUL CLUSTER IN AWS
# These templates show an example of how to use the consul-cluster module to deploy Consul in AWS. We deploy two Auto
# Scaling Groups (ASGs): one with a small number of Consul server nodes and one with a larger number of Consul client
# nodes. Note that these templates assume that the AMI you provide via the ami_id input variable is built from
# the examples/consul-ami/consul.json Packer template.
# ---------------------------------------------------------------------------------------------------------------------

provider "google" {
  project     = "${var.gcp_project}"
  region      = "${var.gcp_region}"
}

terraform {
  required_version = ">= 0.10.0"
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY THE CONSUL SERVER NODES
# ---------------------------------------------------------------------------------------------------------------------

module "consul_servers" {
  # When using these modules in your own templates, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/consul-aws-blueprint.git//modules/consul-cluster?ref=v0.0.1"
  source = "../../modules/consul-cluster"

  gcp_zone = "${var.gcp_zone}"
  cluster_name = "${var.consul_server_cluster_name}"
  cluster_description = "Consul Server cluster"
  cluster_size = "${var.consul_server_cluster_size}"
  machine_type = "n1-standard-1"
  assign_public_ip_addresses = false
  source_image = "consul"
  cluster_tag_name = "${var.cluster_tag_name}"
  startup_script = "${data.template_file.startup_script_server.rendered}"

  # WARNING! This update strategy will delete and re-create the entire Consul cluster when making some changes to this
  # module. Unfortunately, Google and Terraform do not yet support a stable way of performing a rolling update. For now
  # for production usage, set this to "NONE", and manually coordinate your Consul Server upgrades per Consul docs.
  instance_group_update_strategy = "RESTART"

  # Remove this if you don't want a load balancer.
  instance_group_target_pools = ["${module.load_balancer.target_pool_url}"]
}

# Render the Startup Script that will run on each Consul Server Instance on boot.
# This script will configure and start Consul.
data "template_file" "startup_script_server" {
  template = "${file("${path.module}/startup-script-server.sh")}"

  vars {
    cluster_tag_name = "${var.cluster_tag_name}"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY THE CONSUL CLIENT NODES
# Note that you do not have to use the consul-cluster module to deploy your clients. We do so simply because it
# provides a convenient way to deploy an Instance Group with the necessary configuration for running Consul as a client,
# but feel free to deploy those clients however you choose (e.g. a single Compute Instance, a Docker cluster, etc).
# ---------------------------------------------------------------------------------------------------------------------

module "consul_clients" {
  # When using these modules in your own templates, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/consul-aws-blueprint.git//modules/consul-cluster?ref=v0.0.1"
  source = "../../modules/consul-cluster"

  gcp_zone = "${var.gcp_zone}"
  cluster_name = "${var.consul_client_cluster_name}"
  cluster_size = "${var.consul_client_cluster_size}"
  cluster_description = "Consul Clients cluster"
  machine_type = "n1-standard-1"
  assign_public_ip_addresses = true
  source_image = "consul"
  cluster_tag_name = "${var.cluster_tag_name}"
  startup_script = "${data.template_file.startup_script_client.rendered}"

  # Our Consul Clients are completely stateless, so we are free to destroy and re-create them as needed.
  instance_group_update_strategy = "RESTART"
}

# Render the Startup Script that will run on each Consul Server Instance on boot.
# This script will configure and start Consul.
data "template_file" "startup_script_client" {
  template = "${file("${path.module}/startup-script-client.sh")}"

  vars {
    cluster_tag_name = "${var.cluster_tag_name}"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ADD CUSTOM RESOURCES AS NEEDED
# You may wish to front the Consul Server cluster with a Load Balancer so that you can have a single endpoint for
# accessing the Consul UI, assign a DNS Record or create other custom resources as your needs dicate.
# ---------------------------------------------------------------------------------------------------------------------

module "load_balancer" {
  # When using these modules in your own templates, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/consul-aws-blueprint.git//modules/consul-regional-load-balancer?ref=v0.0.1"
  source = "../../modules/consul-external-regional-load-balancer"

  cluster_name = "${var.consul_server_cluster_name}"
  cluster_tag_name = "${var.cluster_tag_name}"
  compute_instance_group_name = "${module.consul_servers.instance_group_name}"
}