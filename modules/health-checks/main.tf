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

  fqdn              = each.value.fqdn
  ip_address        = each.value.ip_address
  port              = each.value.port
  resource_path     = each.value.resource_path
  search_string     = each.value.search_string
  request_interval  = local.endpoint[each.key] ? each.value.request_interval : null
  failure_threshold = local.endpoint[each.key] ? each.value.failure_threshold : null
  measure_latency   = local.endpoint[each.key] ? each.value.measure_latency : null
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

  tags = merge(var.tags, { Name = each.key }, each.value.tags)
}
