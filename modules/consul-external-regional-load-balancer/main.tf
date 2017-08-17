# ---------------------------------------------------------------------------------------------------------------------
# THESE TEMPLATES REQUIRE TERRAFORM VERSION 0.10.0 AND ABOVE
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  required_version = ">= 0.10.0"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A READY-MADE HEALTH CHECK FOR USE WITH THE CONSUL SERVER CLUSTER
# By itself, a Health Check adds no value. It must be attached to
# ---------------------------------------------------------------------------------------------------------------------

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

# Only used for internal load balancer
resource "google_compute_backend_service" "consul_server" {
  count = "${1 - var.enable_public_access}"

  name = "${var.cluster_name}"
  description = "${var.backend_service_description}"

  enable_cdn  = "${var.backend_service_enable_cdn}"
  port_name   = "${var.backend_service_port_name}"
  protocol    = "${var.backend_service_protocol}"
  session_affinity = "${var.backend_service_session_affinity}"
  timeout_sec = "${var.backend_service_timeout_sec}"
  connection_draining_timeout_sec = "${var.backend_service_connection_draining_timeout_sec}"

  backend {
    group = "${var.compute_instance_group_name}"
    balancing_mode = "${var.backend_service_balancing_mode}"
  }

  health_checks = ["${google_compute_http_health_check.consul_server.self_link}"]
}

# Only used for external load balancer
resource "google_compute_target_pool" "consul_server" {
  count = "${var.enable_public_access}"

  name = "${var.cluster_name}"
  description = "${var.target_pool_description}"
  session_affinity = "${var.target_pool_session_affinity}"
  health_checks = ["${google_compute_http_health_check.consul_server.name}"]
}

resource "google_compute_forwarding_rule" "consul_server" {
  name = "${var.cluster_name}"
  description = "${var.forwarding_rule_description}"

  ip_address = "${var.forwarding_rule_ip_address}"
  ip_protocol = "TCP"
  load_balancing_scheme = "${var.enable_public_access ? "EXTERNAL" : "INTERNAL" }"
  network = "${var.network_name}"
  port_range = "${var.external_load_balancer_port_range}"
  ports = "${var.internal_load_balancer_port_list}"
  subnetwork = "${var.forwarding_rule_subnetwork}"

  # If we have a public Load Balancer, only specify a Target Pool, otherwise only specify a Backend Service.
  target = "${var.enable_public_access ? google_compute_target_pool.consul_server.self_link : ""}"

  # TODO: Fix this
  backend_service = ""
  //backend_service = "${var.enable_public_access ? "" : google_compute_backend_service.consul_server.self_link}"
}

resource "google_compute_firewall" "load_balancer" {
  name    = "${var.cluster_name}-load-balancer"
  network = "${var.network_name}"

  allow {
    protocol = "tcp"
    ports    = ["${var.http_api_port}"]
  }

  source_ranges = ["0.0.0.0/0"]
  # TODO: Fix this
  target_tags = ["consul-server-josh"]
}