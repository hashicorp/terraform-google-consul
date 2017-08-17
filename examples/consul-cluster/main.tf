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
  cluster_name = "${var.cluster_name}"
  cluster_description = "Consul Server cluster"
  machine_type = "n1-standard-1"
  assign_public_ip_addresses = true
  instance_group_update_strategy = "RESTART"
  source_image = "consul"
  cluster_tag_name = "${var.cluster_tag_name}"
  startup_script = "${data.template_file.startup_script_server.rendered}"
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
# ADD CUSTOM RESOURCES AS NEEDED
# You may wish to front the Consul Server cluster with a Load Balancer so that you can have a single endpoint for
# accessing the Consul UI, assign a DNS Record or create other custom resources as your needs dicate.
# ---------------------------------------------------------------------------------------------------------------------