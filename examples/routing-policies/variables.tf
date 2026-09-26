variable "region" {
  description = "AWS region the provider talks to. Route 53 is global; the region only selects the API endpoint."
  type        = string
  default     = "us-east-1"
}

variable "zone_id" {
  description = "ID of the existing hosted zone that receives the records."
  type        = string
}

variable "us_east_1_ipv4_address" {
  description = "Public IPv4 address of the endpoint in us-east-1; it must answer HTTPS on /health."
  type        = string

  validation {
    condition     = can(cidrhost("${var.us_east_1_ipv4_address}/32", 0))
    error_message = "us_east_1_ipv4_address must be a valid IPv4 address."
  }
}

variable "eu_west_1_ipv4_address" {
  description = "Public IPv4 address of the endpoint in eu-west-1; it must answer HTTPS on /health."
  type        = string

  validation {
    condition     = can(cidrhost("${var.eu_west_1_ipv4_address}/32", 0))
    error_message = "eu_west_1_ipv4_address must be a valid IPv4 address."
  }
}

variable "tags" {
  description = "Tags applied to every health check."
  type        = map(string)
  default     = {}
}
