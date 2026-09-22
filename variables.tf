variable "zone_name" {
  description = "Hosted-zone name, without relying on an implicit trailing dot."
  type        = string
  default     = null
  nullable    = true
}

variable "zone_id" {
  description = "Existing Route 53 hosted-zone ID. Required unless create_zone is true."
  type        = string
  default     = null
  nullable    = true
}

variable "create_zone" {
  description = "Whether to create a public hosted zone."
  type        = bool
  default     = false
}

variable "force_destroy" {
  description = "Whether a managed zone may be destroyed with records. Keep false in production."
  type        = bool
  default     = false
}

variable "records" {
  description = "Record sets keyed by a stable logical name. Alias and records are mutually exclusive."
  type = map(object({
    name    = string
    type    = string
    ttl     = optional(number)
    records = optional(set(string))
    alias = optional(object({
      name                   = string
      zone_id                = string
      evaluate_target_health = optional(bool, false)
    }))
  }))
  default = {}
}

variable "tags" {
  description = "Tags applied when the module creates a hosted zone."
  type        = map(string)
  default     = {}
}
