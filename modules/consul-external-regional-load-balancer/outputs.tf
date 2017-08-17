output "target_pool_url" {
  value = "${google_compute_target_pool.consul_server.self_link}"
}