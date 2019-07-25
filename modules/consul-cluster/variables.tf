# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# You must provide a value for each of these parameters.
# ---------------------------------------------------------------------------------------------------------------------

variable "gcp_project_id" {
  description = "The project to deploy the cluster in"
  type        = string
}

variable "gcp_region" {
  description = "All GCP resources will be launched in this Region."
  type        = string
}

variable "cluster_name" {
  description = "The name of the Consul cluster (e.g. consul-stage). This variable is used to namespace all resources created by this module."
  type        = string
}

variable "cluster_tag_name" {
  description = "The tag name the Compute Instances will look for to automatically discover each other and form a cluster. TIP: If running more than one Consul Server cluster, each cluster should have its own unique tag name."
  type        = string
}

variable "machine_type" {
  description = "The machine type of the Compute Instance to run for each node in the cluster (e.g. n1-standard-1)."
  type        = string
}

variable "cluster_size" {
  description = "The number of nodes to have in the Consul cluster. We strongly recommended that you use either 3 or 5."
  type        = number
}

variable "source_image" {
  description = "The source image used to create the boot disk for a Consul Server node. Only images based on Ubuntu 16.04 or 18.04 LTS are supported at this time."
  type        = string
}

variable "startup_script" {
  description = "A Startup Script to execute when the server first boots. We remmend passing in a bash script that executes the run-consul script, which should have been installed in the Consul Google Image by the install-consul module."
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# These parameters have reasonable defaults.
# ---------------------------------------------------------------------------------------------------------------------

variable "image_project_id" {
  description = "The name of the GCP Project where the image is located. Useful when using a separate project for custom images. If empty, var.gcp_project_id will be used."
  type        = string
  default     = null
}

variable "network_project_id" {
  description = "The name of the GCP Project where the network is located. Useful when using networks shared between projects. If empty, var.gcp_project_id will be used."
  type        = string
  default     = null
}

variable "service_account_scopes" {
  description = "A list of service account scopes that will be added to the Compute Instance Template in addition to the scopes automatically added by this module."
  type        = list(string)
  default     = []
}

variable "storage_access_scope" {
  description = "Used to set the access permissions for Google Cloud Storage. As of September 2018, this must be one of ['', 'storage-ro', 'storage-rw', 'storage-full']"
  type        = string
  default     = "storage-ro"
}

variable "instance_group_target_pools" {
  description = "To use a Load Balancer with the Consul cluster, you must populate this value. Specifically, this is the list of Target Pool URLs to which new Compute Instances in the Instance Group created by this module will be added. Note that updating the Target Pools attribute does not affect existing Compute Instances. Note also that use of a Load Balancer with Consul is generally discouraged; client should instead prefer to talk directly to the server where possible."
  type        = list(string)
  default     = []
}

variable "cluster_description" {
  description = "A description of the Consul cluster; it will be added to the Compute Instance Template."
  type        = string
  default     = null
}

variable "assign_public_ip_addresses" {
  description = "If true, each of the Compute Instances will receive a public IP address and be reachable from the Public Internet (if Firewall rules permit). If false, the Compute Instances will have private IP addresses only. In production, this should be set to false."
  type        = bool
  default     = false
}

variable "network_name" {
  description = "The name of the VPC Network where all resources should be created."
  type        = string
  default     = "default"
}

variable "subnetwork_name" {
  description = "The name of the VPC Subnetwork where all resources should be created. Defaults to the default subnetwork for the network and region."
  type        = string
  default     = null
}

variable "custom_tags" {
  description = "A list of tags that will be added to the Compute Instance Template in addition to the tags automatically added by this module."
  type        = list(string)
  default     = []
}

variable "service_account_email" {
  description = "The email of the service account for the instance template. If none is provided the google cloud provider project service account is used."
  type        = string
  default     = null
}

variable "instance_group_update_strategy" {
  description = "The update strategy to be used by the Instance Group. IMPORTANT! When you update almost any cluster setting, under the hood, this module creates a new Instance Group Template. Once that Instance Group Template is created, the value of this variable determines how the new Template will be rolled out across the Instance Group. Unfortunately, as of August 2017, Google only supports the options 'RESTART' (instantly restart all Compute Instances and launch new ones from the new Template) or 'NONE' (do nothing; updates should be handled manually). Google does offer a rolling updates feature that perfectly meets our needs, but this is in Alpha (https://goo.gl/MC3mfc). Therefore, until this module supports a built-in rolling update strategy, we recommend using `NONE` and using the alpha rolling updates strategy to roll out new Consul versions. As an alpha feature, be sure you are comfortable with the level of risk you are taking on. For additional detail, see https://goo.gl/hGH6dd."
  type        = string
  default     = "NONE"
}

variable "allowed_inbound_cidr_blocks_http_api" {
  description = "A list of CIDR-formatted IP address ranges from which the Compute Instances will allow API connections to Consul."
  type        = list(string)
  default     = []
}

variable "allowed_inbound_tags_http_api" {
  description = "A list of tags from which the Compute Instances will allow API connections to Consul."
  type        = list(string)
  default     = []
}

variable "allowed_inbound_cidr_blocks_dns" {
  description = "A list of CIDR-formatted IP address ranges from which the Compute Instances will allow TCP DNS and UDP DNS connections to Consul."
  type        = list(string)
  default     = []
}

variable "allowed_inbound_tags_dns" {
  description = "A list of tags from which the Compute Instances will allow TCP DNS and UDP DNS connections to Consul."
  type        = list(string)
  default     = []
}

# Metadata

variable "metadata_key_name_for_cluster_size" {
  description = "The key name to be used for the custom metadata attribute that represents the size of the Consul cluster."
  type        = string
  default     = "cluster-size"
}

variable "custom_metadata" {
  description = "A map of metadata key value pairs to assign to the Compute Instance metadata."
  type        = map(string)
  default     = {}
}

# Firewall Ports

variable "server_rpc_port" {
  description = "The port used by servers to handle incoming requests from other agents."
  type        = number
  default     = 8300
}

variable "cli_rpc_port" {
  description = "The port used by all agents to handle RPC from the CLI."
  type        = number
  default     = 8400
}

variable "serf_lan_port" {
  description = "The port used to handle gossip in the LAN. Required by all agents."
  type        = number
  default     = 8301
}

variable "serf_wan_port" {
  description = "The port used by servers to gossip over the WAN to other servers."
  type        = number
  default     = 8302
}

variable "http_api_port" {
  description = "The port used by clients to talk to the HTTP API"
  type        = number
  default     = 8500
}

variable "dns_port" {
  description = "The port used to resolve DNS queries."
  type        = number
  default     = 8600
}

# Disk Settings

variable "root_volume_disk_size_gb" {
  description = "The size, in GB, of the root disk volume on each Consul node."
  type        = number
  default     = 30
}

variable "root_volume_disk_type" {
  description = "The GCE disk type. Can be either pd-ssd, local-ssd, or pd-standard"
  type        = string
  default     = "pd-standard"
}
