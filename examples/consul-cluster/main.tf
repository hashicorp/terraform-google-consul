# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY A CONSUL CLUSTER IN GOOGLE CLOUD
# These templates show an example of how to use the consul-cluster module to deploy Consul in Google Cloud. We deploy two
# Compute Instance Groups: one with Consul server nodes and one with Consul client nodes. Note that these templates assume
# that the Custom Image you provide via the source_image input variable is built from the
# examples/consul-image/consul.json Packer template.
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
  # source = "git::git@github.com:gruntwork-io/consul-gcp-module.git//modules/consul-cluster?ref=v0.0.1"
  source = "../../modules/consul-cluster"

  gcp_zone = "${var.gcp_zone}"
  cluster_name = "${var.consul_server_cluster_name}"
  cluster_description = "Consul Server cluster"
  cluster_size = "${var.consul_server_cluster_size}"
  machine_type = "g1-small"
  assign_public_ip_addresses = true
  source_image = "consul"
  cluster_tag_name = "${var.consul_server_cluster_tag_name}"
  startup_script = "${data.template_file.startup_script_server.rendered}"

  # Grant API and DNS access to requests originating from the the Consul client cluster we create below.
  allowed_inbound_tags_http_api = ["${var.consul_client_cluster_tag_name}"]
  allowed_inbound_tags_dns = ["${var.consul_client_cluster_tag_name }"]

  # WARNING! This update strategy will delete and re-create the entire Consul cluster when making some changes to this
  # module. Unfortunately, Google and Terraform do not yet support an automatic stable way of performing a rolling update.
  # For now for production usage, set this to "NONE", and manually coordinate your Consul Server upgrades per Consul docs.
  instance_group_update_strategy = "NONE"
}

# Render the Startup Script that will run on each Consul Server Instance on boot.
# This script will configure and start Consul.
data "template_file" "startup_script_server" {
  template = "${file("${path.module}/startup-script-server.sh")}"

  vars {
    cluster_tag_name = "${var.consul_server_cluster_tag_name}"
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
  # source = "git::git@github.com:gruntwork-io/consul-gcp-module.git//modules/consul-cluster?ref=v0.0.1"
  source = "../../modules/consul-cluster"

  gcp_zone = "${var.gcp_zone}"
  cluster_name = "${var.consul_client_cluster_name}"
  cluster_size = "${var.consul_client_cluster_size}"
  cluster_description = "Consul Clients cluster"
  machine_type = "n1-standard-1"
  assign_public_ip_addresses = true
  source_image = "consul"
  cluster_tag_name = "${var.consul_client_cluster_tag_name}"
  startup_script = "${data.template_file.startup_script_client.rendered}"

  allowed_inbound_cidr_blocks_http_api = []
  allowed_inbound_tags_http_api = []

  allowed_inbound_cidr_blocks_dns = []
  allowed_inbound_tags_dns = []

  # Our Consul Clients are completely stateless, so we are free to destroy and re-create them as needed.
  instance_group_update_strategy = "RESTART"
}

# Render the Startup Script that will run on each Consul Server Instance on boot.
# This script will configure and start Consul.
data "template_file" "startup_script_client" {
  template = "${file("${path.module}/startup-script-client.sh")}"

  vars {
    cluster_tag_name = "${var.consul_server_cluster_tag_name}"
  }
}