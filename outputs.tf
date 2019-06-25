output "gcp_project" {
  description = "The GCP Project where all resources are deployed."
  value       = var.gcp_project_id
}

output "gcp_region" {
  description = "The GCP region where all resources are deployed."
  value       = module.consul_servers.gcp_region
}

output "cluster_size" {
  description = "The number of servers in the Consul Server cluster."
  value       = var.consul_server_cluster_size
}

output "cluster_tag_name" {
  description = "The tag assigned to each Consul Server node that is used to discover other Consul Server nodes."
  value       = var.consul_server_cluster_tag_name
}

output "instance_group_name" {
  description = "The name of the Managed Instance Group that contains the Consul Server cluster."
  value       = module.consul_servers.instance_group_name
}

output "instance_group_url" {
  description = "The URL of the Managed Instance Group that contains the Consul Server cluster."
  value       = module.consul_servers.instance_group_url
}

output "client_instance_group_name" {
  description = "The name of the Managed Instance Group that contains the Consul Client cluster."
  value       = module.consul_clients.instance_group_name
}

output "instance_template_metadata_fingerprint" {
  description = "A hash computed by the unique combination of metadata associated with the Instance Template used by the Consul Server cluster."
  value       = module.consul_servers.instance_template_metadata_fingerprint
}

output "instance_template_name" {
  description = "The name of the Instance Template used by the Consul Server cluster."
  value       = module.consul_servers.instance_template_name
}

output "instance_template_url" {
  description = "The URL of the Instance Template used by the Consul Server cluster."
  value       = module.consul_servers.instance_template_url
}

