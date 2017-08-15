variable "gcp_project" {
  description = "The name of the GCP Project where all resources will be launched."
  default = "consul-176820"
}

variable "gcp_region" {
  description = "The region in which all GCP resources will be launched."
  default = "us-west-1"
}

//variable "gcp_zone" {
//  description = "The zone in which all GCP resources will be launched."
//  default = "us-west-1a"
//}