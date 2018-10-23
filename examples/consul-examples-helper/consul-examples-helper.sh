#!/bin/bash
# A script that is meant to be used with the Consul cluster examples to:
#
# 1. Wait for the Consul server cluster to come up.
# 2. Print out the IP addresses of the Consul servers.
# 3. Print out some example commands you can run against your Consul servers.
#
# This script has been tested for use with Consul v0.9.x.

set -e

readonly SCRIPT_NAME="$(basename "$0")"

readonly MAX_RETRIES=30
readonly SLEEP_BETWEEN_RETRIES_SEC=10

function log {
  local -r level="$1"
  local -r message="$2"
  local -r timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  >&2 echo -e "${timestamp} [${level}] [$SCRIPT_NAME] ${message}"
}

function log_info {
  local -r message="$1"
  log "INFO" "$message"
}

function log_warn {
  local -r message="$1"
  log "WARN" "$message"
}

function log_error {
  local -r message="$1"
  log "ERROR" "$message"
}

function assert_is_installed {
  local -r name="$1"

  if [[ ! $(command -v ${name}) ]]; then
    log_error "The binary '$name' is required by this script but is not installed or in the system's PATH."
    exit 1
  fi
}

function get_required_terraform_output {
  local -r output_name="$1"
  local output_value

  output_value=$(terraform output -no-color "$output_name")

  if [[ -z "$output_value" ]]; then
    log_error "Unable to find a value for Terraform output \"$output_name\"."
    log_error "Are you running this command from the same folder from which you ran \"terraform apply\"?"
    exit 1
  fi

  echo "$output_value"
}

#
# Usage: join SEPARATOR ARRAY
#
# Joins the elements of ARRAY with the SEPARATOR character between them.
#
# Examples:
#
# join ", " ("A" "B" "C")
#   Returns: "A, B, C"
#
function join {
  local -r separator="$1"
  shift
  local -r values=("$@")

  printf "%s$separator" "${values[@]}" | sed "s/$separator$//"
}

function get_all_consul_server_property_values {
  local server_property_name="$1"

  local gcp_project
  local gcp_region
  local cluster_tag_name
  local expected_num_servers

  gcp_project=$(get_required_terraform_output "gcp_project") || exit 1
  gcp_region=$(get_required_terraform_output "gcp_region") || exit 1
  cluster_tag_name=$(get_required_terraform_output "cluster_tag_name") || exit 1
  expected_num_servers=$(get_required_terraform_output "cluster_size") || exit 1

  log_info "Looking up $server_property_name for $expected_num_servers Consul server Compute Instances."

  local vals
  local i

  for (( i=1; i<="$MAX_RETRIES"; i++ )); do
    vals=($(get_consul_server_property_values "$gcp_project" "$gcp_region" "$cluster_tag_name" "$server_property_name"))
    if [[ "${#vals[@]}" -eq "$expected_num_servers" ]]; then
      log_info "Found $server_property_name for all $expected_num_servers expected Consul servers!"
      echo "${vals[@]}"
      return
    else
      log_warn "Found $server_property_name for ${#vals[@]} of $expected_num_servers Consul servers. Will sleep for $SLEEP_BETWEEN_RETRIES_SEC seconds and try again."
      sleep "$SLEEP_BETWEEN_RETRIES_SEC"
    fi
  done

  log_error "Failed to find the $server_property_name for $expected_num_servers Consul server Compute Instances after $MAX_RETRIES retries."
  exit 1
}

function wait_for_all_consul_servers_to_register {
  local -r server_ips=($@)
  local -r server_ip="${server_ips[0]}"

  local expected_num_servers
  expected_num_servers=$(get_required_terraform_output "cluster_size") || exit 1

  log_info "Waiting for $expected_num_servers Consul servers to register in the cluster"

  for (( i=1; i<="$MAX_RETRIES"; i++ )); do
    log_info "Running 'consul members' command against server at IP address $server_ip"
    # Intentionally use local and readonly here so that this script doesn't exit if the consul members or grep commands
    # exit with an error.
    local members=$(consul members -http-addr="$server_ip:8500")
    local server_members=$(echo "$members" | grep "server")
    local num_servers=$(echo "$server_members" | wc -l | tr -d ' ')

    if [[ "$num_servers" -eq "$expected_num_servers" ]]; then
      log_info "All $expected_num_servers Consul servers have registered in the cluster!"
      return
    else
      log_info "$num_servers out of $expected_num_servers Consul servers have registered in the cluster."
      log_info "Sleeping for $SLEEP_BETWEEN_RETRIES_SEC seconds and will check again."
      sleep "$SLEEP_BETWEEN_RETRIES_SEC"
    fi
  done

  log_error "Did not find $expected_num_servers Consul servers registered after $MAX_RETRIES retries."
  exit 1
}

function get_consul_server_property_values {
  local -r gcp_project="$1"
  local -r gcp_region="$2"
  local -r cluster_tag_name="$3"
  local -r property_name="$4"
  local instances

  log_info "Fetching external IP addresses for Consul Server Compute Instances with tag \"$cluster_tag_name\""

  instances=$(gcloud compute instances list \
    --project "$gcp_project"\
    --filter "zone : $gcp_region" \
    --filter "tags.items~^$cluster_tag_name\$" \
    --format "value($property_name)")

  echo "$instances"
}

function get_all_consul_server_ips {
  get_all_consul_server_property_values "EXTERNAL_IP"
}

function print_instructions {
  local -r server_ips=($@)
  local -r server_ip="${server_ips[0]}"

  local instructions=()
  instructions+=("\nYour Consul servers are running at the following IP addresses:\n\n${server_ips[@]/#/    }\n")
  instructions+=("Some commands for you to try:\n")
  instructions+=("    consul members -http-addr=$server_ip:8500")
  instructions+=("    consul kv put -http-addr=$server_ip:8500 foo bar")
  instructions+=("    consul kv get -http-addr=$server_ip:8500 foo")
  instructions+=("\nTo see the Consul UI, open the following URL in your web browser:\n")
  instructions+=("    http://$server_ip:8500/ui/\n")

  local instructions_str
  instructions_str=$(join "\n" "${instructions[@]}")

  echo -e "$instructions_str"
}

function run {
  assert_is_installed "gcloud"
  assert_is_installed "terraform"
  assert_is_installed "consul"

  local server_ips
  server_ips=$(get_all_consul_server_ips)

  wait_for_all_consul_servers_to_register "$server_ips"
  print_instructions "$server_ips"
}

run
