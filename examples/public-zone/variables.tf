variable "region" {
  description = "AWS region the provider talks to. Route 53 is global; the region only selects the API endpoint."
  type        = string
  default     = "us-east-1"
}

variable "zone_name" {
  description = "Name of the public hosted zone to create, for example example.com."
  type        = string
}

variable "www_ipv4_addresses" {
  description = "IPv4 addresses the apex and www records answer with."
  type        = list(string)

  validation {
    condition     = length(var.www_ipv4_addresses) > 0 && alltrue([for address in var.www_ipv4_addresses : can(cidrhost("${address}/32", 0))])
    error_message = "www_ipv4_addresses must hold at least one valid IPv4 address."
  }
}

variable "tags" {
  description = "Tags applied to the hosted zone."
  type        = map(string)
  default     = {}
}
