# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# You must provide a value for each of these parameters.
# ---------------------------------------------------------------------------------------------------------------------

variable "cluster_name" {
  description = "The name of the Consul cluster (e.g. consul-stage). This variable is used to namespace all resources created by this module."
}

variable "compute_instance_group_name" {
  description = "The name of the Compute Instance Group that contains the Consul Server nodes."
}

variable "enable_public_access" {
  description = "If true, public access will be allowed to the Load Balancer. If false, only in-network access will be allowed."
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# These parameters have reasonable defaults.
# ---------------------------------------------------------------------------------------------------------------------

variable "http_api_port" {
  description = "The port used by clients to talk to the Consul Server HTTP API"
  default = 8500
}

variable "network_name" {
  description = "The name of the VPC Network where all resources should be created."
  default = "default"
}

# Health Check options

variable "health_check_request_path" {
  description = "The URL path the Health Check will query. Note that the default requires that Raft Protocol version 3 or higher be used. This is the default setting when running the run-consul module in this repo."
  default = "/v1/operator/autopilot/health"
}

variable "health_check_interval_sec" {
  description = "The number of seconds between each Health Check attempt."
  default = 5
}

variable "health_check_timeout_sec" {
  description = "The number of seconds to wait before the Health Check declares failure."
  default = 3
}

variable "health_check_healthy_threshold" {
  description = "The number of consecutive successes required to consider the Compute Instance healthy."
  default = 2
}

variable "health_check_unhealthy_threshold" {
  description = "The number of consecutive failures required to consider the Compute Instance unhealthy."
  default = 1
}

# Forwarding Rule Options

variable "forwarding_rule_description" {
  description = "The description added to the Forwarding Rule created by this module."
  default = ""
}

variable "forwarding_rule_ip_address" {
  description = "The static IP address to assign to the Forwarding Rule. If not set, an ephemeral IP address is used."
  default = ""
}

variable "external_load_balancer_port_range" {
  description = "A range (e.g. 1024-2048) or a single port (1024) on which the Load Balancer will accept inbound connections. The empty string means all ports. Must be used if var.enable_public_access == true; otherwise leave empty."
  default = ""
}

variable "internal_load_balancer_port_list" {
  description = "A list of ports (maximum of 5) on which the internal Load Balancer will accept inbound connections. Must be used if var.enable_public_access == false; otherwise leave empty."
  type = "list"
  default = []
}

variable "forwarding_rule_subnetwork" {
  description = "The Subnetwork that the load balanced IP should belong to. Must be specified if the network is in custom subnet mode. Only used if var.enable_public_access == false."
  default = ""
}

# Target Pool Options

variable "target_pool_description" {
  description = "The description added to the Target Pool created by this module. Unless var.enable_public_access == true, this setting is ignored."
  default = ""
}

variable "target_pool_session_affinity" {
  description = "How to distribute load across the Target Pool. Options are NONE (no affinity), CLIENT_IP (hash of the source/dest addresses/ports), and CLIENT_IP_PROTO also includes the protocol. Unless var.enable_public_access == true, this setting is ignored."
  default = "NONE"
}

# Backend Service Options

variable "backend_service_description" {
  description = "The description added to the Backend Service created by this module. Unless var.enable_public_access == false, this setting is ignored."
  default = "Enables a Health Check on the Consul Server cluster."
}

variable "backend_service_balancing_mode" {
  description = "Defines the strategy for balancing load. Valid values are UTILIZATION, RATE (for HTTP(S)) and CONNECTION (for TCP/SSL). This cannot be used for internal load balancing. Unless var.enable_public_access == false, this setting is ignored."
  default = "UTILIZATION"
}

variable "backend_service_enable_cdn" {
  description = "If true, enables the Cloud CDN on the backend service. Unless var.enable_public_access == false, this setting is ignored."
  default = ""
}
variable "backend_service_port_name" {
  description = "The name of a service that has been added to an Instance Group in the Backend. Unless var.enable_public_access == false, this setting is ignored."
  default = "http"
}
variable "backend_service_protocol" {
  description = "The protocol the Backend Service will use to communicate with Backends. Options are HTTP, HTTPS, TCP, and SSL. For internal load balancing, options are TCP and UDP. Unless var.enable_public_access == false, this setting is ignored."
  default = "HTTP"
}

variable "backend_service_session_affinity" {
  description = "How to distribute load. Options are NONE (no affinity), CLIENT_IP (hash of the source/dest addresses/ports), and GENERATED_COOKIE (distribute load using a generated session cookie). Unless var.enable_public_access == false, this setting is ignored."
  default = "NONE"
}
variable "backend_service_timeout_sec" {
  default = "The number of seconds to wait for a Backend to respond to a request before considering the request failed. Unless var.enable_public_access == false, this setting is ignored."
  default = 5
}
variable "backend_service_connection_draining_timeout_sec" {
  default = "The number of seconds for which a Compute Instance will be drained (not accept new connections, but still work to finish started ones). Unless var.enable_public_access == false, this setting is ignored."
  default = 0
}