variable "zone_id" {
  description = "Hosted zone the record sets belong to. Required whenever records is non-empty; the resource precondition names it."
  type        = string
  default     = null

  validation {
    condition     = var.zone_id == null ? true : can(regex("^Z[0-9A-Z]{1,31}$", var.zone_id))
    error_message = "zone_id must be a Route 53 hosted zone ID (Z followed by up to 31 uppercase alphanumerics), not a zone name."
  }
}

variable "default_ttl" {
  description = "TTL in seconds applied to non-alias records that declare no ttl."
  type        = number
  default     = 300
  nullable    = false

  validation {
    condition     = var.default_ttl >= 0 && var.default_ttl <= 2147483647
    error_message = "default_ttl must be between 0 and 2147483647 seconds."
  }
}

variable "records" {
  description = "Record sets keyed by a stable identifier. name is relative to the zone or a fully qualified name; empty or @ is the apex. Exactly one of records or alias; at most one routing policy, which requires set_identifier. TXT and SPF values must carry their own double quotes (\"v=spf1 -all\"); values longer than 255 characters are split into quoted chunks by the caller."
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
    set_identifier  = optional(string)
    health_check_id = optional(string)
    weighted = optional(object({
      weight = number
    }))
    latency = optional(object({
      region = string
    }))
    failover = optional(object({
      type = string
    }))
    geolocation = optional(object({
      continent   = optional(string)
      country     = optional(string)
      subdivision = optional(string)
    }))
    geoproximity = optional(object({
      aws_region       = optional(string)
      local_zone_group = optional(string)
      bias             = optional(number)
      coordinates = optional(object({
        latitude  = string
        longitude = string
      }))
    }))
    cidr = optional(object({
      collection_id = string
      location_name = string
    }))
    multivalue_answer = optional(bool, false)
    allow_overwrite   = optional(bool, false)
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for record in values(var.records) : contains(["A", "AAAA", "CAA", "CNAME", "DS", "HTTPS", "MX", "NAPTR", "NS", "PTR", "SOA", "SPF", "SRV", "SSHFP", "SVCB", "TLSA", "TXT"], record.type)])
    error_message = "type must be one of A, AAAA, CAA, CNAME, DS, HTTPS, MX, NAPTR, NS, PTR, SOA, SPF, SRV, SSHFP, SVCB, TLSA, or TXT."
  }

  validation {
    condition     = alltrue([for record in values(var.records) : (record.alias != null) != (record.records == null ? false : length(record.records) > 0)])
    error_message = "Each record must declare exactly one of alias or a non-empty records set."
  }

  validation {
    condition     = alltrue([for record in values(var.records) : record.alias == null ? true : record.ttl == null])
    error_message = "Alias records take their TTL from the target; ttl must not be set with alias."
  }

  validation {
    condition     = alltrue([for record in values(var.records) : record.ttl == null ? true : (record.ttl >= 0 && record.ttl <= 2147483647)])
    error_message = "ttl must be between 0 and 2147483647 seconds."
  }

  validation {
    condition     = alltrue([for record in values(var.records) : length([for policy in [record.weighted, record.latency, record.failover, record.geolocation, record.geoproximity, record.cidr] : policy if policy != null]) + (record.multivalue_answer ? 1 : 0) <= 1])
    error_message = "A record may use at most one routing policy: weighted, latency, failover, geolocation, geoproximity, cidr, or multivalue_answer."
  }

  validation {
    condition     = alltrue([for record in values(var.records) : (length([for policy in [record.weighted, record.latency, record.failover, record.geolocation, record.geoproximity, record.cidr] : policy if policy != null]) + (record.multivalue_answer ? 1 : 0) > 0) == (record.set_identifier != null)])
    error_message = "set_identifier is required with a routing policy (including multivalue_answer) and must be omitted without one."
  }

  validation {
    condition     = alltrue([for record in values(var.records) : record.set_identifier == null ? true : (length(record.set_identifier) >= 1 && length(record.set_identifier) <= 128)])
    error_message = "set_identifier must be 1 to 128 characters."
  }

  validation {
    condition     = alltrue([for record in values(var.records) : record.health_check_id == null ? true : (length([for policy in [record.weighted, record.latency, record.failover, record.geolocation, record.geoproximity, record.cidr] : policy if policy != null]) + (record.multivalue_answer ? 1 : 0) > 0)])
    error_message = "health_check_id has no effect on a simple record; Route 53 evaluates health checks only with a routing policy (weighted, latency, failover, geolocation, geoproximity, cidr, or multivalue_answer)."
  }

  validation {
    condition     = alltrue([for record in values(var.records) : record.multivalue_answer ? record.alias == null : true])
    error_message = "multivalue_answer records cannot be alias records."
  }

  validation {
    condition     = alltrue([for record in values(var.records) : record.type == "CNAME" ? !contains(["", "@"], record.name) : true])
    error_message = "A CNAME cannot exist at the zone apex; use an alias record instead."
  }

  validation {
    condition     = alltrue([for record in values(var.records) : (record.type == "CNAME" && record.records != null) ? length(record.records) == 1 : true])
    error_message = "A CNAME record set holds exactly one value."
  }

  validation {
    condition     = alltrue([for record in values(var.records) : (contains(["NS", "SOA"], record.type) && contains(["", "@"], record.name)) ? record.allow_overwrite : true])
    error_message = "Route 53 creates the apex NS and SOA record sets with the zone; managing them requires allow_overwrite = true."
  }

  validation {
    condition     = alltrue([for record in values(var.records) : record.failover == null ? true : contains(["PRIMARY", "SECONDARY"], record.failover.type)])
    error_message = "failover.type must be PRIMARY or SECONDARY."
  }

  validation {
    condition     = alltrue([for record in values(var.records) : record.weighted == null ? true : (record.weighted.weight >= 0 && record.weighted.weight <= 255)])
    error_message = "weighted.weight must be between 0 and 255."
  }

  validation {
    condition     = alltrue([for record in values(var.records) : record.latency == null ? true : can(regex("^[a-z]{2}(-[a-z]+)+-[0-9]$", record.latency.region))])
    error_message = "latency.region must be an AWS region code such as us-east-1."
  }

  validation {
    condition = alltrue([for record in values(var.records) : record.geolocation == null ? true : (
      (record.geolocation.continent != null) != (record.geolocation.country != null) &&
      (record.geolocation.subdivision == null ? true : record.geolocation.country != null)
    )])
    error_message = "geolocation must set exactly one of continent or country (use country = \"*\" for the default location); subdivision requires country."
  }

  validation {
    condition = alltrue([for record in values(var.records) : record.geoproximity == null ? true : (
      length([for location in [record.geoproximity.aws_region, record.geoproximity.local_zone_group, record.geoproximity.coordinates] : location if location != null]) == 1 &&
      (record.geoproximity.bias == null ? true : (record.geoproximity.bias >= -99 && record.geoproximity.bias <= 99))
    )])
    error_message = "geoproximity must set exactly one of aws_region, local_zone_group, or coordinates; bias must be between -99 and 99."
  }
}
