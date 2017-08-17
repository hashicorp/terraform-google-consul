output "gcp_zone" {
  value = "${var.gcp_zone}"
}

output "instance_group_url" {
  value = "${google_compute_instance_group_manager.consul_server.self_link}"
}

output "instance_group_name" {
  value = "${google_compute_instance_group_manager.consul_server.name}"
}

output "instance_template_url" {
  value = "${data.template_file.compute_instance_template_self_link.rendered}"
}

output "instance_template_name" {
  value = "${element(concat(google_compute_instance_template.consul_server_public.*.name, google_compute_instance_template.consul_server_private.*.name), 0)}"
}

output "instance_template_metadata_fingerprint" {
  value = "${element(concat(google_compute_instance_template.consul_server_public.*.metadata_fingerprint, google_compute_instance_template.consul_server_private.*.metadata_fingerprint), 0)}"
}

output "firewall_rule_url" {
  value = "${google_compute_firewall.consul_server.self_link}"
}

output "firewall_rule_name" {
  value = "${google_compute_firewall.consul_server.name}"
}
