# Consul Examples Helper

This folder contains a helper script called `consul-examples-helper.sh` for working with the 
[consul-cluster example](https://github.com/gruntwork-io/terraform-google-consul/examples/consul-cluster). After running `terraform apply` on the example, if you run 
`consul-examples-helper.sh`, it will automatically:

1. Wait for the Consul server cluster to come up.
1. Print out the IP addresses of the Consul servers.
1. Print out some example commands you can run against your Consul servers.

**NOTE: To use this script be sure that `assign_public_ip_addresses` is set to `true` for the Consul Server cluster.**
