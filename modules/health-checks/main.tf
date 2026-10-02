# One aws_route53_health_check per map entry. Attributes are rendered only for
# the check types that accept them, so a calculated, CloudWatch, or recovery
# control check never carries endpoint settings.

locals {
  endpoint_types = ["HTTP", "HTTPS", "HTTP_STR_MATCH", "HTTPS_STR_MATCH", "TCP"]
  endpoint       = { for key, check in var.health_checks : key => contains(local.endpoint_types, check.type) }
}

resource "aws_route53_health_check" "this" {
  for_each = var.health_checks

  type = each.value.type

  fqdn          = each.value.fqdn
  ip_address    = each.value.ip_address
  port          = each.value.port
  resource_path = each.value.resource_path
  search_string = each.value.search_string

  # Endpoint-only settings: the variable rejects them on other types, so the
  # defaults (30 seconds, 3 failures, no latency) apply to endpoint checks only.
  request_interval  = local.endpoint[each.key] ? coalesce(each.value.request_interval, 30) : null
  failure_threshold = local.endpoint[each.key] ? coalesce(each.value.failure_threshold, 3) : null
  measure_latency   = local.endpoint[each.key] ? coalesce(each.value.measure_latency, false) : null
  enable_sni        = each.value.enable_sni
  regions           = each.value.regions

  invert_healthcheck = each.value.invert_healthcheck
  disabled           = each.value.disabled

  child_healthchecks     = each.value.child_healthchecks
  child_health_threshold = each.value.child_health_threshold

  cloudwatch_alarm_name           = each.value.cloudwatch_alarm_name
  cloudwatch_alarm_region         = each.value.cloudwatch_alarm_region
  insufficient_data_health_status = each.value.insufficient_data_health_status

  routing_control_arn = each.value.routing_control_arn

  # The module's Name only fills a gap: module-level tags, then per-check tags,
  # are merged on top of it, so a caller-supplied Name always wins.
  tags = merge({ Name = each.key }, var.tags, each.value.tags)
}
