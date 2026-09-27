variable "health_checks" {
  description = "Health checks keyed by a stable identifier. type selects the shape: HTTP, HTTPS, HTTP_STR_MATCH, HTTPS_STR_MATCH, and TCP probe an endpoint (fqdn or ip_address); CALCULATED aggregates child_healthchecks; CLOUDWATCH_METRIC follows an alarm; RECOVERY_CONTROL follows a routing control. Attributes that do not apply to the type are rejected."
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

  validation {
    condition     = alltrue([for check in values(var.health_checks) : contains(["HTTP", "HTTPS", "HTTP_STR_MATCH", "HTTPS_STR_MATCH", "TCP", "CALCULATED", "CLOUDWATCH_METRIC", "RECOVERY_CONTROL"], check.type)])
    error_message = "type must be one of HTTP, HTTPS, HTTP_STR_MATCH, HTTPS_STR_MATCH, TCP, CALCULATED, CLOUDWATCH_METRIC, or RECOVERY_CONTROL."
  }

  validation {
    condition     = alltrue([for check in values(var.health_checks) : contains(["HTTP", "HTTPS", "HTTP_STR_MATCH", "HTTPS_STR_MATCH", "TCP"], check.type) ? (check.fqdn != null || check.ip_address != null) : (check.fqdn == null && check.ip_address == null && check.port == null && check.resource_path == null && check.search_string == null && check.regions == null && check.enable_sni == null)])
    error_message = "Endpoint checks (HTTP, HTTPS, HTTP_STR_MATCH, HTTPS_STR_MATCH, TCP) need fqdn or ip_address; CALCULATED, CLOUDWATCH_METRIC, and RECOVERY_CONTROL checks accept none of fqdn, ip_address, port, resource_path, search_string, regions, or enable_sni."
  }

  validation {
    condition     = alltrue([for check in values(var.health_checks) : check.ip_address == null ? true : (can(cidrhost("${check.ip_address}/32", 0)) || can(cidrhost("${check.ip_address}/128", 0)))])
    error_message = "ip_address must be a valid IPv4 or IPv6 address."
  }

  validation {
    condition     = alltrue([for check in values(var.health_checks) : check.port == null ? true : (check.port >= 1 && check.port <= 65535)])
    error_message = "port must be between 1 and 65535."
  }

  validation {
    condition     = alltrue([for check in values(var.health_checks) : check.type == "TCP" ? (check.port != null && check.resource_path == null && check.search_string == null) : true])
    error_message = "TCP checks require port and accept neither resource_path nor search_string."
  }

  validation {
    condition     = alltrue([for check in values(var.health_checks) : check.resource_path == null ? true : (startswith(check.resource_path, "/") && length(check.resource_path) <= 255)])
    error_message = "resource_path must start with / and be at most 255 characters."
  }

  validation {
    condition     = alltrue([for check in values(var.health_checks) : contains(["HTTP_STR_MATCH", "HTTPS_STR_MATCH"], check.type) ? (check.search_string == null ? false : (length(check.search_string) >= 1 && length(check.search_string) <= 255)) : check.search_string == null])
    error_message = "search_string (1-255 characters) is required for HTTP_STR_MATCH and HTTPS_STR_MATCH and not accepted by other types."
  }

  validation {
    condition     = alltrue([for check in values(var.health_checks) : contains([10, 30], check.request_interval) && check.failure_threshold >= 1 && check.failure_threshold <= 10])
    error_message = "request_interval must be 10 or 30 seconds and failure_threshold between 1 and 10."
  }

  validation {
    condition     = alltrue([for check in values(var.health_checks) : check.enable_sni == null ? true : contains(["HTTPS", "HTTPS_STR_MATCH"], check.type)])
    error_message = "enable_sni applies to HTTPS and HTTPS_STR_MATCH checks only."
  }

  validation {
    condition     = alltrue([for check in values(var.health_checks) : check.regions == null ? true : (length(check.regions) >= 3 && alltrue([for region in check.regions : contains(["us-east-1", "us-west-1", "us-west-2", "eu-west-1", "ap-southeast-1", "ap-southeast-2", "ap-northeast-1", "sa-east-1"], region)]))])
    error_message = "regions must name at least three Route 53 health-checker regions: us-east-1, us-west-1, us-west-2, eu-west-1, ap-southeast-1, ap-southeast-2, ap-northeast-1, sa-east-1."
  }

  validation {
    condition = alltrue([for check in values(var.health_checks) : check.type == "CALCULATED" ? (
      check.child_healthchecks != null && check.child_health_threshold != null &&
      length(coalesce(check.child_healthchecks, [])) >= 1 && length(coalesce(check.child_healthchecks, [])) <= 256 &&
      coalesce(check.child_health_threshold, -1) >= 0 && coalesce(check.child_health_threshold, -1) <= length(coalesce(check.child_healthchecks, []))
      ) : (check.child_healthchecks == null && check.child_health_threshold == null)
    ])
    error_message = "CALCULATED checks require 1-256 child_healthchecks and a child_health_threshold between 0 and the number of children; other types accept neither."
  }

  validation {
    condition = alltrue([for check in values(var.health_checks) : check.type == "CLOUDWATCH_METRIC" ? (
      check.cloudwatch_alarm_name != null && check.cloudwatch_alarm_region != null &&
      (check.insufficient_data_health_status == null ? true : contains(["Healthy", "Unhealthy", "LastKnownStatus"], check.insufficient_data_health_status))
      ) : (check.cloudwatch_alarm_name == null && check.cloudwatch_alarm_region == null && check.insufficient_data_health_status == null)
    ])
    error_message = "CLOUDWATCH_METRIC checks require cloudwatch_alarm_name and cloudwatch_alarm_region, with insufficient_data_health_status one of Healthy, Unhealthy, or LastKnownStatus; other types accept none of them."
  }

  validation {
    condition     = alltrue([for check in values(var.health_checks) : check.type == "RECOVERY_CONTROL" ? can(regex("^arn:[a-z-]+:route53-recovery-control::[0-9]{12}:controlpanel/[0-9a-f]+/routingcontrol/[0-9a-f]+$", coalesce(check.routing_control_arn, "unset"))) : check.routing_control_arn == null])
    error_message = "RECOVERY_CONTROL checks require routing_control_arn (arn:<partition>:route53-recovery-control::<account>:controlpanel/<id>/routingcontrol/<id>); other types do not accept it."
  }
}

variable "tags" {
  description = "Tags applied to every health check. Per-check tags are merged on top and the module adds Name = <key>."
  type        = map(string)
  default     = {}
  nullable    = false
}
