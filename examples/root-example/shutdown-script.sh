#!/bin/bash
# This script is meant to be run as the Shutdown Script of each Compute Instance while it's stopping. The script uses 
# systemd to shutdown Consul which triggers the consul leave command. Note that this script assumes it's running in a
# Google Image built from the Packer template in examples/consul-image/consul.json.

set -e

# Send the log output from this script to shutdown-script.log, syslog, and the console
# Inspired by https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee /var/log/shutdown-script.log|logger -t shutdown-script -s 2>/dev/console) 2>&1

systemctl stop consul.service
