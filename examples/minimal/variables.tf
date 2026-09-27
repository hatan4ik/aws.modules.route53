variable "region" {
  description = "AWS region the provider talks to. Route 53 is global; the region only selects the API endpoint."
  type        = string
  default     = "us-east-1"
}

variable "zone_id" {
  description = "ID of the existing hosted zone that receives the records."
  type        = string
}

variable "www_ipv4_addresses" {
  description = "IPv4 addresses the www record answers with."
  type        = list(string)

  validation {
    condition     = length(var.www_ipv4_addresses) > 0 && alltrue([for address in var.www_ipv4_addresses : can(cidrhost("${address}/32", 0))])
    error_message = "www_ipv4_addresses must hold at least one valid IPv4 address."
  }
}
