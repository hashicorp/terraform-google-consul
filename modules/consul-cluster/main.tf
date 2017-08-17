# ---------------------------------------------------------------------------------------------------------------------
# THESE TEMPLATES REQUIRE TERRAFORM VERSION 0.10.0 AND ABOVE
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  required_version = ">= 0.10.0"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A GCE INSTANCE GROUP TO RUN CONSUL SERVER
# Ideally, we would run a "regional" Managed Instance Group that spans many Zones, but the Terraform GCP provider has
# not yet implemented https://github.com/terraform-providers/terraform-provider-google/issues/45, so we settle for a
# single-zone Managed Instance Group.
# ---------------------------------------------------------------------------------------------------------------------

# Create the single-zone Managed Instance Group where Consul Server will live.
resource "google_compute_instance_group_manager" "consul_server" {
  name = "${var.cluster_name}"

  base_instance_name = "${var.cluster_name}"
  instance_template  = "${data.template_file.compute_instance_template_self_link.rendered}"
  zone               = "${var.gcp_zone}"

  # Consul Server is a stateful cluster, so the update strategy used to roll out a new GCE Instance Template must be
  # a rolling update. But since Terraform does not yet support ROLLING_UPDATE, such updates must be manually rolled out.
  update_strategy = "${var.instance_group_update_strategy}"

  #target_pools = ["${google_compute_target_pool.appserver.self_link}"]
  target_size  = "${var.cluster_size}"

  depends_on = ["google_compute_instance_template.consul_server_public", "google_compute_instance_template.consul_server_private"]
}

# Create the Instance Template that will be used to populate the Managed Instance Group.
# NOTE: This Compute Instance Template is only created if var.assign_public_ip_addresses is true.
resource "google_compute_instance_template" "consul_server_public" {
  count = "${var.assign_public_ip_addresses}"

  name_prefix = "${var.cluster_name}"
  description = "${var.cluster_description}"
  tags = "${concat(list(var.cluster_tag_name), var.custom_network_tags)}"

  instance_description = "${var.cluster_description}"
  machine_type         = "${var.machine_type}"
  metadata_startup_script = "${var.startup_script}"

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
    # The presence of this property assigns a public IP address to each Compute Instance.
    access_config {
      nat_ip = ""
    }
  }

  metadata = "${merge(map(var.metadata_key_name_for_cluster_size, var.cluster_size), var.custom_metadata)}"

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
  tags = "${concat(list(var.cluster_tag_name), var.custom_network_tags)}"

  instance_description = "${var.cluster_description}"
  machine_type         = "${var.machine_type}"

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

  metadata = "${var.custom_metadata}"

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

# Add a Health Check so that GCE will auto-restart unhealthy instances
# WARNING: This Health Check requires that the Raft Protocol be set to 3 or higher. If you wish to use a lower Raft
# Protocol version, you should disable this Health Check by setting var.enable_health_check = false.
resource "google_compute_http_health_check" "consul_server" {
  name = "${var.cluster_name}"

  request_path = "${var.health_check_request_path}"
  port = "${var.http_api_port}"
  check_interval_sec = "${var.health_check_interval_sec}"
  timeout_sec = "${var.health_check_timeout_sec}"
  healthy_threshold = "${var.health_check_healthy_threshold}"
  unhealthy_threshold = "${var.health_check_unhealthy_threshold}"
}

# ---------------------------------------------------------------------------------------------------------------------
# UPDATE FIREWALL RULES TO ALLOW CONSUL-SPECIFIC TRAFFIC WITHIN CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

resource "google_compute_firewall" "consul_server" {
  name    = "${var.cluster_name}"
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