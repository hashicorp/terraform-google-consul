# ---------------------------------------------------------------------------------------------------------------------
# THESE TEMPLATES REQUIRE TERRAFORM VERSION 0.8 AND ABOVE
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  required_version = ">= 0.10.0"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A GCE INSTANCE GROUP TO RUN CONSUL SERVER
# Ideally, we would run a "regional" Managed Instance Group that spans many Zones, but the Terraform GCP provider has
# not yet implemented https://github.com/terraform-providers/terraform-provider-google/issues/45, so we settle for a
# single-zone Managed Instance Group.
# ---------------------------------------------------------------------------------------------------------------------

# Create the single-zone Managed Instance Group where Consul Server will live.
resource "google_compute_instance_group_manager" "consul_server" {
  name = "${var.cluster_name}"

  base_instance_name = "${var.cluster_name}"
  instance_template  = "${data.template_file.compute_instance_template_self_link.rendered}"
  zone               = "${var.gcp_zone}"

  # Consul Server is a stateful cluster, so the update strategy used to roll out a new GCE Instance Template must be
  # a rolling update. But since Terraform does not yet support ROLLING_UPDATE, such updates must be manually rolled out.
  update_strategy = "${var.instance_group_update_strategy}"

  #target_pools = ["${google_compute_target_pool.appserver.self_link}"]
  target_size  = "${var.cluster_size}"
}

# Create the Instance Template that will be used to populate the Managed Instance Group.
# NOTE: This Compute Instance Template is only created if var.assign_public_ip_addresses is true.
resource "google_compute_instance_template" "consul_server_public" {
  count = "${var.assign_public_ip_addresses}"

  name_prefix = "${var.cluster_name}"
  description = "${var.cluster_description}"
  tags = "${concat(list(var.cluster_tag_name), var.custom_network_tags)}"

  instance_description = "${var.cluster_description}"
  machine_type         = "${var.machine_type}"
  metadata_startup_script = "${var.startup_script}"

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
    preemptible = false
  }

  disk {
    boot         = true
    auto_delete  = true
    source_image = "${var.source_image}"

  }

  network_interface {
    network = "${var.network_name}"
    # The presence of this property assigns a public IP address to each Compute Instance.
    access_config {
      nat_ip = ""
    }
  }

  metadata = "${merge(map(var.metadata_key_name_for_cluster_size, var.cluster_size), var.custom_metadata)}"

  service_account {
    scopes = ["userinfo-email", "compute-ro", "storage-ro"]
  }

  # Per Terraform Docs (https://www.terraform.io/docs/providers/google/r/compute_instance_template.html#using-with-instance-group-manager),
  # we need to create a new instance template before we can destroy the old one. Note that any Terraform resource on
  # which this Terraform resource depends will also need this lifecycle statement.
  lifecycle {
    create_before_destroy = true
  }
}

# Create the Instance Template that will be used to populate the Managed Instance Group.
# NOTE: This Compute Instance Template is only created if var.assign_public_ip_addresses is false.
resource "google_compute_instance_template" "consul_server_private" {
  count = "${1 - var.assign_public_ip_addresses}"

  name_prefix = "${var.cluster_name}"
  description = "${var.cluster_description}"
  tags = "${concat(list(var.cluster_tag_name), var.custom_network_tags)}"

  instance_description = "${var.cluster_description}"
  machine_type         = "${var.machine_type}"

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
    preemptible = false
  }

  disk {
    boot         = true
    auto_delete  = true
    source_image = "${var.source_image}"
  }

  network_interface {
    network = "${var.network_name}"
  }

  metadata = "${var.custom_metadata}"

  service_account {
    scopes = ["userinfo-email", "compute-ro", "storage-ro"]
  }

  # Per Terraform Docs (https://www.terraform.io/docs/providers/google/r/compute_instance_template.html#using-with-instance-group-manager),
  # we need to create a new instance template before we can destroy the old one. Note that any Terraform resource on
  # which this Terraform resource depends will also need this lifecycle statement.
  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# UPDATE FIREWALL RULES TO ALLOW CONSUL-SPECIFIC TRAFFIC WITHIN CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

resource "google_compute_firewall" "consul_server" {
  name    = "${var.cluster_name}"
  network = "${var.network_name}"

  allow {
    protocol = "tcp"
    ports    = [
      "${var.server_rpc_port}",
      "${var.cli_rpc_port}",
      "${var.serf_lan_port}",
      "${var.serf_wan_port}",
      "${var.http_api_port}",
      "${var.dns_port}"
    ]
  }

  allow {
    protocol = "udp"
    ports    = [
      "${var.serf_lan_port}",
      "${var.serf_wan_port}",
      "${var.dns_port}"
    ]
  }

  source_tags = ["${var.cluster_tag_name}"]
}

# ---------------------------------------------------------------------------------------------------------------------
# CONVENIENCE VARIABLES
# Because we've got some conditional logic in this template, some values will depend on our properties. This section
# wraps such values in a nicer construct.
# ---------------------------------------------------------------------------------------------------------------------

# The Google Compute Instance Group needs the self_link of the Compute Instance Template that's actually created.
data "template_file" "compute_instance_template_self_link" {
  # This will return the self_link of the Compute Instance Template that is actually created. It works as follows:
  # - Make a list of 1 value or 0 values for each of google_compute_instance_template.consul_servers_public and
  #   google_compute_instance_template.consul_servers_private by adding the glob (*) notation. Terraform will complain
  #   if we directly reference a resource property that doesn't exist, but it will permit us to turn a single resource
  #   into a list of 1 resource and "no resource" into an empty list.
  # - Concat these lists. concat(list-of-1-value, empty-list) == list-of-1-value
  # - Take the first element of list-of-1-value
  template = "${element(concat(google_compute_instance_template.consul_server_public.*.self_link, google_compute_instance_template.consul_server_private.*.self_link), 0)}"
}


//resource "aws_autoscaling_group" "autoscaling_group" {
//  launch_configuration = "${aws_launch_configuration.launch_configuration.name}"
//
//  availability_zones  = ["${var.availability_zones}"]
//  vpc_zone_identifier = ["${var.subnet_ids}"]
//
//  # Run a fixed number of instances in the ASG
//  min_size             = "${var.cluster_size}"
//  max_size             = "${var.cluster_size}"
//  desired_capacity     = "${var.cluster_size}"
//  termination_policies = ["${var.termination_policies}"]
//
//  target_group_arns         = ["${var.target_group_arns}"]
//  load_balancers            = ["${var.load_balancers}"]
//  health_check_type         = "${var.health_check_type}"
//  health_check_grace_period = "${var.health_check_grace_period}"
//  wait_for_capacity_timeout = "${var.wait_for_capacity_timeout}"
//
//  tag {
//    key                 = "Name"
//    value               = "${var.cluster_name}"
//    propagate_at_launch = true
//  }
//
//  tag {
//    key                 = "${var.cluster_tag_key}"
//    value               = "${var.cluster_tag_value}"
//    propagate_at_launch = true
//  }
//}
//
//# ---------------------------------------------------------------------------------------------------------------------
//# CREATE LAUCNH CONFIGURATION TO DEFINE WHAT RUNS ON EACH INSTANCE IN THE ASG
//# ---------------------------------------------------------------------------------------------------------------------
//
//resource "aws_launch_configuration" "launch_configuration" {
//  name_prefix   = "${var.cluster_name}-"
//  image_id      = "${var.ami_id}"
//  instance_type = "${var.instance_type}"
//  user_data     = "${var.user_data}"
//
//  iam_instance_profile        = "${aws_iam_instance_profile.instance_profile.name}"
//  key_name                    = "${var.ssh_key_name}"
//  security_groups             = ["${aws_security_group.lc_security_group.id}"]
//  placement_tenancy           = "${var.tenancy}"
//  associate_public_ip_address = "${var.associate_public_ip_address}"
//
//  ebs_optimized = "${var.root_volume_ebs_optimized}"
//
//  root_block_device {
//    volume_type           = "${var.root_volume_type}"
//    volume_size           = "${var.root_volume_size}"
//    delete_on_termination = "${var.root_volume_delete_on_termination}"
//  }
//
//  # Important note: whenever using a launch configuration with an auto scaling group, you must set
//  # create_before_destroy = true. However, as soon as you set create_before_destroy = true in one resource, you must
//  # also set it in every resource that it depends on, or you'll get an error about cyclic dependencies (especially when
//  # removing resources). For more info, see:
//  #
//  # https://www.terraform.io/docs/providers/aws/r/launch_configuration.html
//  # https://terraform.io/docs/configuration/resources.html
//  lifecycle {
//    create_before_destroy = true
//  }
//}
//
//# ---------------------------------------------------------------------------------------------------------------------
//# CREATE A SECURITY GROUP TO CONTROL WHAT REQUESTS CAN GO IN AND OUT OF EACH EC2 INSTANCE
//# ---------------------------------------------------------------------------------------------------------------------
//
//resource "aws_security_group" "lc_security_group" {
//  name_prefix = "${var.cluster_name}"
//  description = "Security group for the ${var.cluster_name} launch configuration"
//  vpc_id      = "${var.vpc_id}"
//
//  # aws_launch_configuration.launch_configuration in this module sets create_before_destroy to true, which means
//  # everything it depends on, including this resource, must set it as well, or you'll get cyclic dependency errors
//  # when you try to do a terraform destroy.
//  lifecycle {
//    create_before_destroy = true
//  }
//}
//
//resource "aws_security_group_rule" "allow_ssh_inbound" {
//  type        = "ingress"
//  from_port   = "${var.ssh_port}"
//  to_port     = "${var.ssh_port}"
//  protocol    = "tcp"
//  cidr_blocks = ["${var.allowed_ssh_cidr_blocks}"]
//
//  security_group_id = "${aws_security_group.lc_security_group.id}"
//}
//
//resource "aws_security_group_rule" "allow_all_outbound" {
//  type        = "egress"
//  from_port   = 0
//  to_port     = 0
//  protocol    = "-1"
//  cidr_blocks = ["0.0.0.0/0"]
//
//  security_group_id = "${aws_security_group.lc_security_group.id}"
//}
//
//
//# ---------------------------------------------------------------------------------------------------------------------
//# THE CONSUL-SPECIFIC INBOUND/OUTBOUND RULES COME FROM THE CONSUL-SECURITY-GROUP-RULES MODULE
//# ---------------------------------------------------------------------------------------------------------------------
//
//module "security_group_rules" {
//  source = "../consul-security-group-rules"
//
//  security_group_id           = "${aws_security_group.lc_security_group.id}"
//  allowed_inbound_cidr_blocks = ["${var.allowed_inbound_cidr_blocks}"]
//
//  server_rpc_port = "${var.server_rpc_port}"
//  cli_rpc_port    = "${var.cli_rpc_port}"
//  serf_lan_port   = "${var.serf_lan_port}"
//  serf_wan_port   = "${var.serf_wan_port}"
//  http_api_port   = "${var.http_api_port}"
//  dns_port        = "${var.dns_port}"
//}
//
//# ---------------------------------------------------------------------------------------------------------------------
//# ATTACH AN IAM ROLE TO EACH EC2 INSTANCE
//# We can use the IAM role to grant the instance IAM permissions so we can use the AWS CLI without having to figure out
//# how to get our secret AWS access keys onto the box.
//# ---------------------------------------------------------------------------------------------------------------------
//
//resource "aws_iam_instance_profile" "instance_profile" {
//  name_prefix = "${var.cluster_name}"
//  path        = "${var.instance_profile_path}"
//  role        = "${aws_iam_role.instance_role.name}"
//
//  # aws_launch_configuration.launch_configuration in this module sets create_before_destroy to true, which means
//  # everything it depends on, including this resource, must set it as well, or you'll get cyclic dependency errors
//  # when you try to do a terraform destroy.
//  lifecycle {
//    create_before_destroy = true
//  }
//}
//
//resource "aws_iam_role" "instance_role" {
//  name_prefix        = "${var.cluster_name}"
//  assume_role_policy = "${data.aws_iam_policy_document.instance_role.json}"
//
//  # aws_iam_instance_profile.instance_profile in this module sets create_before_destroy to true, which means
//  # everything it depends on, including this resource, must set it as well, or you'll get cyclic dependency errors
//  # when you try to do a terraform destroy.
//  lifecycle {
//    create_before_destroy = true
//  }
//}
//
//data "aws_iam_policy_document" "instance_role" {
//  statement {
//    effect  = "Allow"
//    actions = ["sts:AssumeRole"]
//
//    principals {
//      type        = "Service"
//      identifiers = ["ec2.amazonaws.com"]
//    }
//  }
//}
//
//
//# ---------------------------------------------------------------------------------------------------------------------
//# THE IAM POLICIES COME FROM THE CONSUL-IAM-POLICIES MODULE
//# ---------------------------------------------------------------------------------------------------------------------
//
//module "iam_policies" {
//  source = "../consul-iam-policies"
//
//  iam_role_id = "${aws_iam_role.instance_role.id}"
//}