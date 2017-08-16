# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY A CONSUL CLUSTER IN AWS
# These templates show an example of how to use the consul-cluster module to deploy Consul in AWS. We deploy two Auto
# Scaling Groups (ASGs): one with a small number of Consul server nodes and one with a larger number of Consul client
# nodes. Note that these templates assume that the AMI you provide via the ami_id input variable is built from
# the examples/consul-ami/consul.json Packer template.
# ---------------------------------------------------------------------------------------------------------------------

provider "google" {
  project     = "${var.gcp_project}"
  region      = "${var.gcp_region}"
}

terraform {
  required_version = ">= 0.10.0"
}

# ---------------------------------------------------------------------------------------------------------------------
//# AUTOMATICALLY LOOK UP THE LATEST PRE-BUILT AMI
//# This repo contains a CircleCI job that automatically builds and publishes the latest AMI by building the Packer
//# template at /examples/consul-ami upon every new release. The Terraform data source below automatically looks up the
//# latest AMI so that a simple "terraform apply" will just work without the user needing to manually build an AMI and
//# fill in the right value.
//#
//# !! WARNING !! These exmaple AMIs are meant only convenience when initially testing this repo. Do NOT use these example
//# AMIs in a production setting because it is important that you consciously think through the configuration you want
//# in your own production AMI.
//#
//# NOTE: This Terraform data source must return at least one AMI result or the entire template will fail. See
//# /_ci/publish-amis-in-new-account.md for more information.
//# ---------------------------------------------------------------------------------------------------------------------
//data "aws_ami" "consul" {
//  most_recent      = true
//
//  # If we change the AWS Account in which test are run, update this value.
//  owners     = ["562637147889"]
//
//  filter {
//    name   = "virtualization-type"
//    values = ["hvm"]
//  }
//
//  filter {
//    name   = "is-public"
//    values = ["true"]
//  }
//
//  filter {
//    name   = "name"
//    values = ["consul-ubuntu-*"]
//  }
//}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY THE CONSUL SERVER NODES
# ---------------------------------------------------------------------------------------------------------------------

module "consul_servers" {
  # When using these modules in your own templates, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/consul-aws-blueprint.git//modules/consul-cluster?ref=v0.0.1"
  source = "../../modules/consul-cluster"

  cluster_name = "josh-test"
  cluster_description = "Consul Server cluster"
  machine_type = "n1-standard-1"
  assign_public_ip_addresses = true
  instance_group_update_strategy = "RESTART"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A BASTION HOST
# Our Consul Server nodes have no public IP address by default, so we create a Bastion Host so that we can reach them.
# ---------------------------------------------------------------------------------------------------------------------