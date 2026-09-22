resource "terraform_data" "input_contract" {
  input = {
    create_zone = var.create_zone
    zone_id     = var.zone_id
    zone_name   = var.zone_name
  }

  lifecycle {
    precondition {
      condition     = (var.create_zone && var.zone_name != null) || (!var.create_zone && var.zone_id != null)
      error_message = "Set zone_name when create_zone is true, otherwise supply an existing zone_id."
    }
  }
}

resource "aws_route53_zone" "this" {
  count = var.create_zone ? 1 : 0

  name          = var.zone_name
  force_destroy = var.force_destroy
  tags          = var.tags
}

locals {
  effective_zone_id = var.create_zone ? aws_route53_zone.this[0].zone_id : var.zone_id
}

resource "aws_route53_record" "this" {
  for_each = var.records

  allow_overwrite = true
  name            = each.value.name
  type            = each.value.type
  zone_id         = local.effective_zone_id
  ttl             = each.value.alias == null ? coalesce(each.value.ttl, 300) : null
  records         = each.value.alias == null ? tolist(coalesce(each.value.records, [])) : null

  dynamic "alias" {
    for_each = each.value.alias == null ? [] : [each.value.alias]

    content {
      name                   = alias.value.name
      zone_id                = alias.value.zone_id
      evaluate_target_health = alias.value.evaluate_target_health
    }
  }

  lifecycle {
    precondition {
      condition     = (each.value.alias == null) != (try(length(each.value.records), 0) > 0)
      error_message = "Each record must set exactly one of alias or non-empty records."
    }
  }
}
