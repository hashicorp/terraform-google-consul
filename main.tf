# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY A CONSUL CLUSTER IN GOOGLE CLOUD
# These templates show an example of how to use the consul-cluster module to deploy Consul in Google Cloud. We deploy two
# Compute Instance Groups: one with Consul server nodes and one with Consul client nodes. Note that these templates assume
# that the Custom Image you provide via the source_image input variable is built from the
# examples/consul-image/consul.json Packer template.
# ---------------------------------------------------------------------------------------------------------------------

provider "google" {
  region = var.gcp_region
}

terraform {
  # The modules used in this example have been updated with 0.12 syntax, which means the example is no longer
  # compatible with any versions below 0.12.
  required_version = ">= 0.12"
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY THE CONSUL SERVER NODES
# ---------------------------------------------------------------------------------------------------------------------

module "consul_servers" {
  # When using these modules in your own templates, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/consul-gcp-module.git//modules/consul-cluster?ref=v0.0.1"
  source = "./modules/consul-cluster"

  gcp_project_id      = var.gcp_project_id
  gcp_region          = var.gcp_region
  cluster_name        = var.consul_server_cluster_name
  cluster_description = "Consul Server cluster"
  cluster_size        = var.consul_server_cluster_size
  cluster_tag_name    = var.consul_server_cluster_tag_name
  startup_script      = data.template_file.startup_script_server.rendered

  # Grant API and DNS access to requests originating from the the Consul client cluster we create below.
  allowed_inbound_tags_http_api        = [var.consul_server_cluster_tag_name]
  allowed_inbound_cidr_blocks_http_api = var.consul_server_allowed_inbound_cidr_blocks_http_api

  allowed_inbound_tags_dns        = [var.consul_server_cluster_tag_name]
  allowed_inbound_cidr_blocks_dns = var.consul_server_allowed_inbound_cidr_blocks_dns

  # WARNING! These configuration values are suitable for testing, but for production, see https://www.consul.io/docs/guides/performance.html
  # Production recommendations:
  # - machine_type: At least n1-standard-2 (so that Consul can use at least 2 cores); confirm that you have enough RAM
  #                 to contain between 2 - 4 times the working set size.
  # - root_volume_disk_type: pd-ssd or local-ssd (for write-heavy workloads, use SSDs for the best write throughput)
  # - root_volume_disk_size_gb: Consul's data set is persisted, so this depends on the size of your expected data set
  machine_type = "g1-small"

  root_volume_disk_type    = "pd-standard"
  root_volume_disk_size_gb = "15"

  # WARNING! By specifying just the "family" name of the Image, Google will automatically use the latest Consul image.
  # In production, you should specify the exact image name to make it clear which image the current Consul servers are
  # deployed with.
  source_image = var.consul_server_source_image

  image_project_id = var.image_project_id

  # WARNING! This makes the Consul cluster accessible from the public Internet, which is convenient for testing, but
  # NOT for production usage. In production, set this to false.
  assign_public_ip_addresses = true

  # WARNING! This update strategy will delete and re-create the entire Consul cluster when making some changes to this
  # module. Unfortunately, Google and Terraform do not yet support an automatic stable way of performing a rolling update.
  # For now for production usage, set this to "NONE", and manually coordinate your Consul Server upgrades per Consul docs.
  instance_group_update_strategy = "NONE"
}

# Render the Startup Script that will run on each Consul Server Instance on boot.
# This script will configure and start Consul.
data "template_file" "startup_script_server" {
  template = file(
    "${path.module}/examples/root-example/startup-script-server.sh",
  )

  vars = {
    cluster_tag_name = var.consul_server_cluster_tag_name
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
  source = "./modules/consul-cluster"

  gcp_project_id      = var.gcp_project_id
  gcp_region          = var.gcp_region
  cluster_name        = var.consul_client_cluster_name
  cluster_description = "Consul Clients cluster"
  cluster_size        = var.consul_client_cluster_size
  cluster_tag_name    = var.consul_client_cluster_tag_name
  startup_script      = data.template_file.startup_script_client.rendered

  allowed_inbound_tags_http_api        = [var.consul_client_cluster_tag_name]
  allowed_inbound_cidr_blocks_http_api = var.consul_client_allowed_inbound_cidr_blocks_http_api

  allowed_inbound_tags_dns        = [var.consul_client_cluster_tag_name]
  allowed_inbound_cidr_blocks_dns = var.consul_client_allowed_inbound_cidr_blocks_dns

  machine_type             = "g1-small"
  root_volume_disk_type    = "pd-standard"
  root_volume_disk_size_gb = "15"

  assign_public_ip_addresses = true

  source_image     = var.consul_client_source_image
  image_project_id = var.image_project_id

  # Our Consul Clients are completely stateless, so we are free to destroy and re-create them as needed.
  # Todo: Research this further
  instance_group_update_strategy = "NONE"
}

# Render the Startup Script that will run on each Consul Server Instance on boot.
# This script will configure and start Consul.
data "template_file" "startup_script_client" {
  template = file(
    "${path.module}/examples/root-example/startup-script-client.sh",
  )

  vars = {
    cluster_tag_name = var.consul_server_cluster_tag_name
  }
}
