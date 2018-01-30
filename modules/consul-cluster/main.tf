# ---------------------------------------------------------------------------------------------------------------------
# THESE TEMPLATES REQUIRE TERRAFORM VERSION 0.10.0 AND ABOVE
# Why? Because we want the latest GCP updates available in https://github.com/terraform-providers/terraform-provider-google
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  required_version = ">= 0.10.0"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A GCE REGION GROUP TO RUN CONSUL SERVER
# ---------------------------------------------------------------------------------------------------------------------
resource "google_compute_region_instance_group_manager" "consul_server" {
  name = "${var.cluster_name}-ig"

  base_instance_name = "${var.cluster_name}"
  instance_template  = "${data.template_file.compute_instance_template_self_link.rendered}"
  region             = "${var.gcp_region}"

  target_pools = ["${var.instance_group_target_pools}"]
  target_size  = "${var.cluster_size}"

  depends_on = ["google_compute_instance_template.consul_server_public", "google_compute_instance_template.consul_server_private"]
}

# Create the Instance Template that will be used to populate the Managed Instance Group.
# NOTE: This Compute Instance Template is only created if var.assign_public_ip_addresses is true.
resource "google_compute_instance_template" "consul_server_public" {
  count = "${var.assign_public_ip_addresses}"

  name_prefix = "${var.cluster_name}"
  description = "${var.cluster_description}"

  instance_description = "${var.cluster_description}"
  machine_type         = "${var.machine_type}"

  tags = "${concat(list(var.cluster_tag_name), var.custom_tags)}"
  metadata_startup_script = "${var.startup_script}"
  metadata = "${merge(map(var.metadata_key_name_for_cluster_size, var.cluster_size), var.custom_metadata)}"

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
    preemptible = false
  }

  disk {
    boot         = true
    auto_delete  = true
    source_image = "${var.source_image}"
    disk_size_gb = "${var.root_volume_disk_size_gb}"
    disk_type    = "${var.root_volume_disk_type}"
  }

  network_interface {
    network = "${var.network_name}"
    access_config {
      # The presence of this property assigns a public IP address to each Compute Instance. We intentionally leave it
      # blank so that an external IP address is selected automatically.
      nat_ip = ""
    }
  }

  service_account {
    scopes = ["userinfo-email", "compute-ro", "storage-ro"]
  }

  # Per Terraform Docs (https://www.terraform.io/docs/providers/google/r/compute_instance_template.html#using-with-instance-group-manager),
  # we need to create a new instance template before we can destroy the old one. Note that any Terraform resource on
  # which this Terraform resource depends will also need this lifecycle statement.
  lifecycle {
    create_before_destroy = true
  }
}

# Create the Instance Template that will be used to populate the Managed Instance Group.
# NOTE: This Compute Instance Template is only created if var.assign_public_ip_addresses is false.
resource "google_compute_instance_template" "consul_server_private" {
  count = "${1 - var.assign_public_ip_addresses}"

  name_prefix = "${var.cluster_name}"
  description = "${var.cluster_description}"

  instance_description = "${var.cluster_description}"
  machine_type = "${var.machine_type}"

  tags = ["${concat(list(var.cluster_tag_name), var.custom_tags)}"]
  metadata_startup_script = "${var.startup_script}"
  metadata = "${merge(map(var.metadata_key_name_for_cluster_size, var.cluster_size), var.custom_metadata)}"

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
    preemptible = false
  }

  disk {
    boot         = true
    auto_delete  = true
    source_image = "${var.source_image}"
  }

  network_interface {
    network = "${var.network_name}"
  }

  service_account {
    scopes = ["userinfo-email", "compute-ro", "storage-ro"]
  }

  # Per Terraform Docs (https://www.terraform.io/docs/providers/google/r/compute_instance_template.html#using-with-instance-group-manager),
  # we need to create a new instance template before we can destroy the old one. Note that any Terraform resource on
  # which this Terraform resource depends will also need this lifecycle statement.
  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE FIREWALL RULES
# ---------------------------------------------------------------------------------------------------------------------

# Allow Consul-specific traffic within the cluster
# - This Firewall Rule may be redundant depnding on the settings of your VPC Network, but if your Network is locked down,
#   this Rule will open up the appropriate ports.
resource "google_compute_firewall" "allow_intracluster_consul" {
  name    = "${var.cluster_name}-rule-cluster"
  network = "${var.network_name}"

  allow {
    protocol = "tcp"
    ports    = [
      "${var.server_rpc_port}",
      "${var.cli_rpc_port}",
      "${var.serf_lan_port}",
      "${var.serf_wan_port}",
      "${var.http_api_port}",
      "${var.dns_port}"
    ]
  }

  allow {
    protocol = "udp"
    ports    = [
      "${var.serf_lan_port}",
      "${var.serf_wan_port}",
      "${var.dns_port}"
    ]
  }

  source_tags = ["${var.cluster_tag_name}"]
  target_tags = ["${var.cluster_tag_name}"]
}

# Specify which traffic is allowed into the Consul Cluster solely for HTTP API requests
# - This Firewall Rule may be redundant depnding on the settings of your VPC Network, but if your Network is locked down,
#   this Rule will open up the appropriate ports.
# - Note that public access to your Consul Cluster will only be permitted if var.assign_public_ip_addresses is true.
# - This Firewall Rule is only created if at least one source tag or source CIDR block is specified.
resource "google_compute_firewall" "allow_inbound_http_api" {
  count = "${length(var.allowed_inbound_cidr_blocks_dns) + length(var.allowed_inbound_tags_dns) > 0 ? 1 : 0}"

  name    = "${var.cluster_name}-rule-external-api-access"
  network = "${var.network_name}"

  allow {
    protocol = "tcp"
    ports    = [
      "${var.http_api_port}",
    ]
  }

  source_ranges = "${var.allowed_inbound_cidr_blocks_http_api}"
  source_tags = ["${var.allowed_inbound_tags_http_api}"]
  target_tags = ["${var.cluster_tag_name}"]
}

# Specify which traffic is allowed into the Consul Cluster solely for DNS requests
# - This Firewall Rule may be redundant depnding on the settings of your VPC Network, but if your Network is locked down,
#   this Rule will open up the appropriate ports.
# - Note that public access to your Consul Cluster will only be permitted if var.assign_public_ip_addresses is true.
# - This Firewall Rule is only created if at least one source tag or source CIDR block is specified.
resource "google_compute_firewall" "allow_inbound_dns" {
  count = "${length(var.allowed_inbound_cidr_blocks_dns) + length(var.allowed_inbound_tags_dns) > 0 ? 1 : 0}"

  name    = "${var.cluster_name}-rule-external-dns-access"
  network = "${var.network_name}"

  allow {
    protocol = "tcp"
    ports    = [
      "${var.dns_port}",
    ]
  }

  allow {
    protocol = "udp"
    ports    = [
      "${var.dns_port}",
    ]
  }

  source_ranges = "${var.allowed_inbound_cidr_blocks_dns}"
  source_tags = ["${var.allowed_inbound_tags_dns}"]
  target_tags = ["${var.cluster_tag_name}"]
}

# ---------------------------------------------------------------------------------------------------------------------
# CONVENIENCE VARIABLES
# Because we've got some conditional logic in this template, some values will depend on our properties. This section
# wraps such values in a nicer construct.
# ---------------------------------------------------------------------------------------------------------------------

# The Google Compute Instance Group needs the self_link of the Compute Instance Template that's actually created.
data "template_file" "compute_instance_template_self_link" {
  # This will return the self_link of the Compute Instance Template that is actually created. It works as follows:
  # - Make a list of 1 value or 0 values for each of google_compute_instance_template.consul_servers_public and
  #   google_compute_instance_template.consul_servers_private by adding the glob (*) notation. Terraform will complain
  #   if we directly reference a resource property that doesn't exist, but it will permit us to turn a single resource
  #   into a list of 1 resource and "no resource" into an empty list.
  # - Concat these lists. concat(list-of-1-value, empty-list) == list-of-1-value
  # - Take the first element of list-of-1-value
  template = "${element(concat(google_compute_instance_template.consul_server_public.*.self_link, google_compute_instance_template.consul_server_private.*.self_link), 0)}"
}
