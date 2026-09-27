variable "region" {
  description = "AWS region the provider talks to. Route 53 is global; the region is also the region of any VPC named in zones."
  type        = string
  default     = "us-east-1"
}

variable "zones" {
  description = "Hosted zones keyed by a stable identifier. vpc_id makes the zone private and creates it in that VPC; without it the zone is public."
  type = map(object({
    name    = string
    comment = optional(string)
    vpc_id  = optional(string)
  }))
}

variable "tags" {
  description = "Tags applied to every hosted zone; the module adds Name and this example adds Zone = <key>."
  type        = map(string)
  default     = {}
}
