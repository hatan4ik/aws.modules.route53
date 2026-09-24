# ---------------------------------------------------------------------------
# Zone: exactly one of zone_id (existing) or zone (created)
# ---------------------------------------------------------------------------

variable "zone_id" {
  description = "ID of an existing hosted zone to manage records, health checks, DNSSEC, and query logging in. Exactly one of zone_id or zone must be set."
  type        = string
  default     = null

  validation {
    condition     = var.zone_id == null ? true : can(regex("^Z[0-9A-Z]{1,31}$", var.zone_id))
    error_message = "zone_id must be a Route 53 hosted zone ID (Z followed by up to 31 uppercase alphanumerics), not a zone name."
  }
}

variable "zone" {
  description = "Hosted zone to create. Public unless private is set; private.vpc_id is the VPC the zone is created in and private.additional_vpcs (keyed by VPC ID, each with an optional region) become standalone associations. force_destroy deletes record sets on destroy. delegation_set_id applies to public zones only. Exactly one of zone_id or zone must be set."
  type = object({
    name              = string
    comment           = optional(string)
    force_destroy     = optional(bool, false)
    delegation_set_id = optional(string)
    private = optional(object({
      vpc_id     = string
      vpc_region = optional(string)
      additional_vpcs = optional(map(object({
        region = optional(string)
      })), {})
    }))
  })
  default = null

  validation {
    condition     = var.zone == null ? true : (can(regex("^([a-z0-9_]([a-z0-9_-]{0,61}[a-z0-9_])?\\.)*[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.?$", var.zone.name)) && length(var.zone.name) <= 254)
    error_message = "zone.name must be a lowercase DNS name (labels of 1-63 letters, digits, hyphens, or underscores, at most 253 characters), optionally ending with a dot."
  }

  validation {
    condition     = var.zone == null ? true : (var.zone.comment == null ? true : length(var.zone.comment) <= 256)
    error_message = "zone.comment must be at most 256 characters."
  }

  validation {
    condition     = var.zone == null ? true : (var.zone.delegation_set_id == null ? true : can(regex("^N[0-9A-Z]{1,31}$", var.zone.delegation_set_id)))
    error_message = "zone.delegation_set_id must be a reusable delegation set ID (N followed by up to 31 uppercase alphanumerics)."
  }

  validation {
    condition     = var.zone == null ? true : (var.zone.private == null ? true : var.zone.delegation_set_id == null)
    error_message = "zone.delegation_set_id applies to public zones only; a private zone cannot use a reusable delegation set."
  }

  validation {
    condition = var.zone == null ? true : (var.zone.private == null ? true : (
      can(regex("^vpc-[0-9a-f]{8,17}$", var.zone.private.vpc_id)) &&
      alltrue([for vpc_id in keys(var.zone.private.additional_vpcs) : can(regex("^vpc-[0-9a-f]{8,17}$", vpc_id))])
    ))
    error_message = "zone.private.vpc_id and every key of zone.private.additional_vpcs must be a VPC ID (vpc-<hex>)."
  }

  validation {
    condition     = var.zone == null ? true : (var.zone.private == null ? true : !contains(keys(var.zone.private.additional_vpcs), var.zone.private.vpc_id))
    error_message = "zone.private.additional_vpcs must not repeat zone.private.vpc_id; the creation VPC is associated by the zone itself."
  }

  validation {
    condition = var.zone == null ? true : (var.zone.private == null ? true : alltrue([
      for region in concat([var.zone.private.vpc_region], [for vpc in values(var.zone.private.additional_vpcs) : vpc.region]) :
      region == null ? true : can(regex("^[a-z]{2}(-[a-z]+)+-[0-9]$", region))
    ]))
    error_message = "zone.private.vpc_region and additional_vpcs[*].region must be AWS region codes such as us-east-1, or null for the provider's region."
  }
}

variable "tags" {
  description = "Tags applied to the hosted zone and every health check. The module adds a Name tag and never overrides caller tags."
  type        = map(string)
  default     = {}
  nullable    = false
}

# ---------------------------------------------------------------------------
# Records and health checks
# ---------------------------------------------------------------------------

variable "records" {
  description = "Record sets keyed by a stable identifier; see modules/records for the routing rules. health_check names a key of health_checks and is resolved to its ID; health_check_id references a check created elsewhere. Either requires a routing policy."
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
    health_check    = optional(string)
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
    condition     = alltrue([for record in values(var.records) : !(record.health_check != null && record.health_check_id != null)])
    error_message = "A record may reference a health check by key (health_check) or by ID (health_check_id), not both."
  }

  validation {
    condition     = alltrue([for record in values(var.records) : record.health_check == null ? true : (length([for policy in [record.weighted, record.latency, record.failover, record.geolocation, record.geoproximity, record.cidr] : policy if policy != null]) + (record.multivalue_answer ? 1 : 0) > 0)])
    error_message = "health_check has no effect on a simple record; Route 53 evaluates health checks only with a routing policy (weighted, latency, failover, geolocation, geoproximity, cidr, or multivalue_answer)."
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

variable "health_checks" {
  description = "Health checks keyed by a stable identifier; see modules/health-checks for the per-type rules. Records reference them by key through health_check."
  type = map(object({
    type                            = string
    fqdn                            = optional(string)
    ip_address                      = optional(string)
    port                            = optional(number)
    resource_path                   = optional(string)
    search_string                   = optional(string)
    request_interval                = optional(number, 30)
    failure_threshold               = optional(number, 3)
    measure_latency                 = optional(bool, false)
    invert_healthcheck              = optional(bool, false)
    disabled                        = optional(bool, false)
    enable_sni                      = optional(bool)
    regions                         = optional(set(string))
    child_healthchecks              = optional(set(string))
    child_health_threshold          = optional(number)
    cloudwatch_alarm_name           = optional(string)
    cloudwatch_alarm_region         = optional(string)
    insufficient_data_health_status = optional(string)
    routing_control_arn             = optional(string)
    tags                            = optional(map(string), {})
  }))
  default  = {}
  nullable = false
}

# ---------------------------------------------------------------------------
# DNSSEC and query logging (public zones only)
# ---------------------------------------------------------------------------

variable "dnssec" {
  description = "Enable DNSSEC signing with a key-signing key backed by kms_key_arn: an asymmetric ECC_NIST_P256 SIGN_VERIFY customer managed key in us-east-1 whose key policy grants dnssec-route53.amazonaws.com kms:DescribeKey, kms:GetPublicKey, kms:Sign, and kms:CreateGrant. Publish output dnssec_key_signing_key.ds_record in the parent zone afterwards. Public zones only."
  type = object({
    kms_key_arn          = string
    key_signing_key_name = optional(string, "ksk")
  })
  default = null

  validation {
    condition     = var.dnssec == null ? true : can(regex("^arn:aws[a-z-]*:kms:us-east-1:[0-9]{12}:key/[0-9a-z-]+$", var.dnssec.kms_key_arn))
    error_message = "dnssec.kms_key_arn must be a KMS key ARN (not an alias) in us-east-1: arn:<partition>:kms:us-east-1:<account>:key/<id>. Route 53 DNSSEC keys must live in us-east-1."
  }

  validation {
    condition     = var.dnssec == null ? true : can(regex("^[A-Za-z0-9_]{3,128}$", var.dnssec.key_signing_key_name))
    error_message = "dnssec.key_signing_key_name must be 3-128 letters, digits, or underscores."
  }
}

variable "query_logging" {
  description = "Send DNS query logs to an existing CloudWatch log group in us-east-1 whose resource policy lets route53.amazonaws.com call logs:CreateLogStream and logs:PutLogEvents. The module does not create the log group. Public zones only."
  type = object({
    cloudwatch_log_group_arn = string
  })
  default = null

  validation {
    condition     = var.query_logging == null ? true : can(regex("^arn:aws[a-z-]*:logs:us-east-1:[0-9]{12}:log-group:[^:*]+(:\\*)?$", var.query_logging.cloudwatch_log_group_arn))
    error_message = "query_logging.cloudwatch_log_group_arn must be a CloudWatch log group ARN in us-east-1: arn:<partition>:logs:us-east-1:<account>:log-group:<name>. Route 53 query logging requires a us-east-1 log group."
  }
}
