variable "region" {
  description = "AWS region of the VPCs. Route 53 is global, but a VPC association needs the VPC's region and the module defaults it to the provider's."
  type        = string
  default     = "us-east-1"
}

variable "zone_name" {
  description = "Name of the private hosted zone to create, for example corp.internal."
  type        = string
}

variable "vpc_id" {
  description = "VPC the zone is created in. It is fixed for the life of the zone."
  type        = string
}

variable "additional_vpc_ids" {
  description = "Further VPCs in the same account and region that resolve the zone, each as a standalone association."
  type        = set(string)
}

variable "database_ipv4_address" {
  description = "Private IPv4 address the db record answers with."
  type        = string

  validation {
    condition     = can(cidrhost("${var.database_ipv4_address}/32", 0))
    error_message = "database_ipv4_address must be a valid IPv4 address."
  }
}

variable "tags" {
  description = "Tags applied to the hosted zone."
  type        = map(string)
  default     = {}
}
