# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# These parameters must be supplied when consuming this module.
# ---------------------------------------------------------------------------------------------------------------------

variable "gcp_project" {
  description = "The name of the GCP Project where all resources will be launched."
}

variable "gcp_region" {
  description = "The region in which all GCP resources will be launched."
}

variable "gcp_zone" {
  description = "The region in which all GCP resources will be launched."
}

variable "consul_server_cluster_name" {
  description = "The name of the Cluster. All resources will be namespaced by this value. E.g. consul-server-prod"
}

variable "consul_client_cluster_name" {
  description = "The name of the Cluster. All resources will be namespaced by this value. E.g. consul-server-prod"
}

variable "cluster_tag_name" {
  description = "The tag the Compute Instances will look for to automatically discover each other and form a cluster. TIP: If running more than one Consul Server cluster, each cluster should have its own unique tag name. If you're not sure what to put for this value, just use the value entered in var.cluster_name."
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# These parameters have reasonable defaults.
# ---------------------------------------------------------------------------------------------------------------------

variable "consul_server_cluster_size" {
  description = "The number of nodes to have in the Consul Server cluster. We strongly recommended that you use either 3 or 5."
  default = 3
}


variable "consul_client_cluster_size" {
  description = "The number of nodes to have in the Consul Client example cluster. Any number of nodes is permissible, though 3 is usually enough to test.."
  default = 3
}