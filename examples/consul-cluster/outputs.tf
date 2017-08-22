output "num_servers" {
  value = "${var.consul_server_cluster_size}"
}

output "gcp_zone" {
  value = "${module.consul_servers.gcp_zone}"
}

output "firewall_rule_name" {
  value = "${module.consul_servers.firewall_rule_name}"
}

output "firewall_rule_url" {
  value = "${module.consul_servers.firewall_rule_url}"
}

output "consul_server_cluster_tag_name" {
  value = "${var.consul_server_cluster_tag_name}"
}

output "consul_servers_instance_group_name" {
  value = "${module.consul_servers.instance_group_name}"
}

output "consul_servers_instance_group_url" {
  value = "${module.consul_servers.instance_group_url}"
}

output "consul_servers_instance_template_metadata_fingerprint" {
  value = "${module.consul_servers.instance_template_metadata_fingerprint}"
}

output "consul_servers_instance_template_name" {
  value = "${module.consul_servers.instance_template_name}"
}

output "consul_servers_instance_template_url" {
  value = "${module.consul_servers.instance_template_url}"
}
