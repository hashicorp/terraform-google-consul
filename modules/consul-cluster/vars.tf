# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# You must provide a value for each of these parameters.
# ---------------------------------------------------------------------------------------------------------------------

variable "gcp_zone" {
  description = "All GCP resources will be launched in this Zone."
}

variable "cluster_name" {
  description = "The name of the Consul cluster (e.g. consul-stage). This variable is used to namespace all resources created by this module."
}

variable "cluster_tag_name" {
  description = "The tag the Compute Instances will look for to automatically discover each other and form a cluster. TIP: If running more than one Consul Server cluster, each cluster should have its own unique tag name"
}

variable "machine_type" {
  description = "The machine type of the Compute Instance to run for each node in the cluster (e.g. n1-standard-1)."
}

variable "startup_script" {
  description = "A Startup Script to execute when the server first boots. We remmend passing in a bash script that executes the run-consul script, which should have been installed in the Consul Google Image by the install-consul module."
}

//variable "allowed_inbound_cidr_blocks" {
//  description = "A list of CIDR-formatted IP address ranges from which the EC2 Instances will allow connections to Consul"
//  type        = "list"
//}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# These parameters have reasonable defaults.
# ---------------------------------------------------------------------------------------------------------------------

variable "source_image" {
  description = "The source image used to create the boot disk for a Consul Server node. Only Ubuntu 16.04 LTS is supported at this time."
  default = "ubuntu-1604-lts"
}

variable "cluster_description" {
  description = "A description of the Consul cluster; it will be added to the Compute Instance Template."
  default = ""
}

variable "assign_public_ip_addresses" {
  description = "If true, each of the Compute Instances will receive a public IP address and be reachable from the Public Internet (if Firewall rules permit). If false, the Compute Instances will have private IP addresses only. In production, this should be set to false."
  default = false
}

variable "cluster_size" {
  description = "The number of nodes to have in the Consul cluster. We strongly recommended that you use either 3 or 5."
  default = 3
}

variable "network_name" {
  description = "The name of the VPC Network where all resources should be created."
  default = "default"
}

variable "custom_network_tags" {
  description = "A list of network tags that will be added to the Compute Instance Template in addition to the tags automatically added by this module."
  type = "list"
  default = []
}

variable "instance_group_target_pools" {
  description = "A list of Target Pool URLs to which new Instances in the Instance Group will be added. Note that updating the Target Pools attribute does not affect existing instances."
  type = "list"
  default = []
}

variable "instance_group_update_strategy" {
  description = "The update strategy to be used by the Instance Group. IMPORTNAT! When you update almost any cluster setting, under the hood, this module creates a new Instance Group Template. Once that Instance Group Template is created, the value of this variable determines how the new Template will be rolled out across the Instance Group. Unfortunately, as of August 2017, Google only supports the options 'RESTART' (instantly restart all Compute Instances and launch new ones from the new Template) or 'NONE' (do nothing; updates should be handled manually). Google does offer a rolling updates feature that perfectly meets our needs, but this is in Alphia (https://goo.gl/MC3mfc). Therefore, until this module supports a built-in rolling update strategy, we recommend using `NONE` and using the alpha rolling updates strategy to roll out new Consul versions. As an alpha feature, be sure you are comfortable with the level of risk you are taking on. For additional detail, see https://goo.gl/hGH6dd."
  default = "NONE"
}

# Metadata

variable "metadata_key_name_for_cluster_size" {
  description = "The key name to be used for the custom metadata attribute that represents the size of the Consul cluster."
  default = "cluster-size"
}

variable "custom_metadata" {
  description = "A map of metadata key value pairs to assign to the Compute Instance metadata."
  type = "map"
  default = {}
}

# Firewall Ports

variable "server_rpc_port" {
  description = "The port used by servers to handle incoming requests from other agents."
  default     = 8300
}

variable "cli_rpc_port" {
  description = "The port used by all agents to handle RPC from the CLI."
  default     = 8400
}

variable "serf_lan_port" {
  description = "The port used to handle gossip in the LAN. Required by all agents."
  default     = 8301
}

variable "serf_wan_port" {
  description = "The port used by servers to gossip over the WAN to other servers."
  default     = 8302
}

variable "http_api_port" {
  description = "The port used by clients to talk to the HTTP API"
  default     = 8500
}

variable "dns_port" {
  description = "The port used to resolve DNS queries."
  default     = 8600
}

//variable "ssh_key_name" {
//  description = "The name of an EC2 Key Pair that can be used to SSH to the EC2 Instances in this cluster. Set to an empty string to not associate a Key Pair."
//  default     = ""
//}
//
//variable "allowed_ssh_cidr_blocks" {
//  description = "A list of CIDR-formatted IP address ranges from which the EC2 Instances will allow SSH connections"
//  type        = "list"
//  default     = []
//}
//
//variable "termination_policies" {
//  description = "A list of policies to decide how the instances in the auto scale group should be terminated. The allowed values are OldestInstance, NewestInstance, OldestLaunchConfiguration, ClosestToNextInstanceHour, Default."
//  default     = "Default"
//}
//
//variable "root_volume_type" {
//  description = "The type of volume. Must be one of: standard, gp2, or io1."
//  default     = "standard"
//}
//
//variable "root_volume_size" {
//  description = "The size, in GB, of the root EBS volume."
//  default     = 50
//}
//
//variable "root_volume_delete_on_termination" {
//  description = "Whether the volume should be destroyed on instance termination."
//  default     = true
//}
//
