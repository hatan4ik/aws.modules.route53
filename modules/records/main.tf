# One aws_route53_record per map entry. Every routing policy is a dynamic
# block that renders only when its object is declared, so a simple record
# carries no policy, no identifier, and no health check.

locals {
  # "@" is the conventional spelling of the apex; the provider expands an
  # empty name to the zone name.
  names = { for key, record in var.records : key => record.name == "@" ? "" : record.name }
}

resource "aws_route53_record" "this" {
  for_each = var.records

  zone_id = var.zone_id
  name    = local.names[each.key]
  type    = each.value.type

  ttl     = each.value.alias == null ? coalesce(each.value.ttl, var.default_ttl) : null
  records = each.value.alias == null ? each.value.records : null

  set_identifier                   = each.value.set_identifier
  health_check_id                  = each.value.health_check_id
  multivalue_answer_routing_policy = each.value.multivalue_answer ? true : null
  allow_overwrite                  = each.value.allow_overwrite

  dynamic "alias" {
    for_each = each.value.alias == null ? [] : [each.value.alias]

    content {
      name                   = alias.value.name
      zone_id                = alias.value.zone_id
      evaluate_target_health = alias.value.evaluate_target_health
    }
  }

  dynamic "weighted_routing_policy" {
    for_each = each.value.weighted == null ? [] : [each.value.weighted]

    content {
      weight = weighted_routing_policy.value.weight
    }
  }

  dynamic "latency_routing_policy" {
    for_each = each.value.latency == null ? [] : [each.value.latency]

    content {
      region = latency_routing_policy.value.region
    }
  }

  dynamic "failover_routing_policy" {
    for_each = each.value.failover == null ? [] : [each.value.failover]

    content {
      type = failover_routing_policy.value.type
    }
  }

  dynamic "geolocation_routing_policy" {
    for_each = each.value.geolocation == null ? [] : [each.value.geolocation]

    content {
      continent   = geolocation_routing_policy.value.continent
      country     = geolocation_routing_policy.value.country
      subdivision = geolocation_routing_policy.value.subdivision
    }
  }

  dynamic "geoproximity_routing_policy" {
    for_each = each.value.geoproximity == null ? [] : [each.value.geoproximity]

    content {
      aws_region       = geoproximity_routing_policy.value.aws_region
      local_zone_group = geoproximity_routing_policy.value.local_zone_group
      bias             = geoproximity_routing_policy.value.bias

      dynamic "coordinates" {
        for_each = geoproximity_routing_policy.value.coordinates == null ? [] : [geoproximity_routing_policy.value.coordinates]

        content {
          latitude  = coordinates.value.latitude
          longitude = coordinates.value.longitude
        }
      }
    }
  }

  dynamic "cidr_routing_policy" {
    for_each = each.value.cidr == null ? [] : [each.value.cidr]

    content {
      collection_id = cidr_routing_policy.value.collection_id
      location_name = cidr_routing_policy.value.location_name
    }
  }

  lifecycle {
    precondition {
      condition     = var.zone_id != null
      error_message = "zone_id is required when records are declared."
    }
  }
}
