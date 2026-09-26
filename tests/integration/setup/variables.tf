variable "name_prefix" {
  description = "Prefix for every disposable fixture; a random suffix is appended so concurrent runs never collide."
  type        = string
  default     = "route53-it"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,38}[a-z0-9])?$", var.name_prefix))
    error_message = "name_prefix must be 1-40 lowercase alphanumeric characters or hyphens."
  }
}

variable "create_vpcs" {
  description = "Also create two VPCs with DNS support and hostnames enabled, for the private-zone suite."
  type        = bool
  default     = false
}

variable "cidr_block" {
  description = "Address space the disposable VPCs are carved from."
  type        = string
  default     = "10.99.0.0/16"
}

variable "tags" {
  description = "Tags applied to every fixture in addition to the identifying defaults."
  type        = map(string)
  default     = {}
}
