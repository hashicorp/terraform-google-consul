variable "gcp_project" {
  description = "The name of the GCP Project where all resources will be launched."
  default = "consul-176820"
}

variable "gcp_region" {
  description = "The region in which all GCP resources will be launched."
  default = "us-west-1"
}

variable "gcp_zone" {
  description = "The region in which all GCP resources will be launched."
  default = "us-west1-a"
}

variable "cluster_name" {
  description = "The name of the Cluster. All resources will be namespaced by this value. E.g. consul-server-prod"
  default = "consul-server-josh"
}

variable "cluster_tag_name" {
  description = "The tag the Compute Instances will look for to automatically discover each other and form a cluster. TIP: If running more than one Consul Server cluster, each cluster should have its own unique tag name. If you're not sure what to put for this value, just use the value entered in var.cluster_name."
  default = "consul-server-josh"
}

//variable "gcp_zone" {
//  description = "The zone in which all GCP resources will be launched."
//  default = "us-west-1a"
//}