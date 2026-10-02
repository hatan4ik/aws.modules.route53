# Drift guard for the schemas the root duplicates from its submodules.
#
# HCL has no type aliases across module boundaries, so the record object type
# exists in variables.tf, modules/records/variables.tf, and (field by field)
# locals.tf, and the health-check object type in variables.tf and
# modules/health-checks/variables.tf. A field added to only one copy would be
# silently dropped or unreachable through the root.
#
# Every run pins the field list of its own copy against the SAME lists below,
# and the root run checks that a fixture setting every field survives the
# forwarding in locals.tf unchanged. Adding a field anywhere fails here until
# it is added to all copies and to these lists.
#
# When this fails: add the field to variables.tf, locals.tf, and the
# submodule's variables.tf, then to the matching list and fixture below.

mock_provider "aws" {}

variables {
  zone_id = "Z0123456789ABCDEFGHIJ"

  # Fields of modules/records var.records; the root adds health_check, which
  # locals.tf resolves into health_check_id.
  expected_record_fields = [
    "alias", "allow_overwrite", "cidr", "failover", "geolocation", "geoproximity",
    "health_check_id", "latency", "multivalue_answer", "name", "records",
    "set_identifier", "ttl", "type", "weighted",
  ]

  # Fields of modules/health-checks var.health_checks; the root forwards the
  # map unchanged, so both copies must be identical.
  expected_health_check_fields = [
    "child_health_threshold", "child_healthchecks", "cloudwatch_alarm_name",
    "cloudwatch_alarm_region", "disabled", "enable_sni", "failure_threshold",
    "fqdn", "insufficient_data_health_status", "invert_healthcheck",
    "ip_address", "measure_latency", "port", "regions", "request_interval",
    "resource_path", "routing_control_arn", "search_string", "tags", "type",
  ]

  # Together these set every record field to a non-null value at least once.
  records = {
    weighted     = { name = "w", type = "A", ttl = 60, records = ["192.0.2.10"], set_identifier = "w", weighted = { weight = 10 }, health_check_id = "0123abcd-4567-89ef-0123-456789abcdef", allow_overwrite = true }
    latency      = { name = "l", type = "A", alias = { name = "d111111abcdef8.cloudfront.net", zone_id = "Z2FDTNDATAQYW2", evaluate_target_health = true }, set_identifier = "l", latency = { region = "us-east-1" } }
    failover     = { name = "f", type = "A", records = ["192.0.2.11"], set_identifier = "f", failover = { type = "PRIMARY" } }
    geolocation  = { name = "g", type = "A", records = ["192.0.2.12"], set_identifier = "g", geolocation = { country = "US", subdivision = "WA" } }
    geoproximity = { name = "p", type = "A", records = ["192.0.2.13"], set_identifier = "p", geoproximity = { coordinates = { latitude = "47.61", longitude = "-122.33" }, bias = 10 } }
    cidr         = { name = "c", type = "A", records = ["192.0.2.14"], set_identifier = "c", cidr = { collection_id = "0123abcd-4567-89ef-0123-456789abcdef", location_name = "office" } }
    multivalue   = { name = "m", type = "A", records = ["192.0.2.15"], set_identifier = "m", multivalue_answer = true }
  }

  # Together these set every health-check field to a non-null value at least once.
  health_checks = {
    endpoint   = { type = "HTTPS_STR_MATCH", fqdn = "app.example.com", ip_address = "192.0.2.10", port = 8443, resource_path = "/health", search_string = "ok", request_interval = 10, failure_threshold = 2, measure_latency = true, invert_healthcheck = true, disabled = true, enable_sni = true, regions = ["us-east-1", "eu-west-1", "ap-southeast-1"], tags = { Team = "web" } }
    calculated = { type = "CALCULATED", child_healthchecks = ["0123abcd-4567-89ef-0123-456789abcdef"], child_health_threshold = 1 }
    alarm      = { type = "CLOUDWATCH_METRIC", cloudwatch_alarm_name = "orders-5xx", cloudwatch_alarm_region = "us-east-1", insufficient_data_health_status = "Healthy" }
    arc        = { type = "RECOVERY_CONTROL", routing_control_arn = "arn:aws:route53-recovery-control::123456789012:controlpanel/0123456789abcdef0123456789abcdef/routingcontrol/abcdef1234567890" }
  }
}

run "root_record_and_health_check_types_match_the_pinned_fields" {
  command = plan

  variables {
    records = merge(var.records, {
      by_key = { name = "k", type = "A", records = ["192.0.2.16"], set_identifier = "k", failover = { type = "SECONDARY" }, health_check = "endpoint" }
    })
  }

  assert {
    condition     = sort(keys(var.records["weighted"])) == sort(concat(var.expected_record_fields, ["health_check"]))
    error_message = "The root records type drifted from the pinned field list (submodule fields plus health_check)."
  }

  assert {
    condition     = alltrue([for field in concat(var.expected_record_fields, ["health_check"]) : anytrue([for record in values(var.records) : record[field] != null && record[field] != false])])
    error_message = "The fixture must set every record field at least once, or the round-trip check below proves nothing for that field."
  }

  assert {
    condition     = sort(keys(var.health_checks["endpoint"])) == sort(var.expected_health_check_fields)
    error_message = "The root health_checks type drifted from the pinned field list."
  }

  assert {
    condition     = alltrue([for field in var.expected_health_check_fields : anytrue([for check in values(var.health_checks) : check[field] != null && check[field] != false])])
    error_message = "The fixture must set every health-check field at least once."
  }
}

run "locals_forward_every_record_field_unchanged" {
  command = plan

  assert {
    condition     = alltrue([for key, record in local.records : sort(keys(record)) == sort(var.expected_record_fields)])
    error_message = "locals.tf must forward exactly the fields of modules/records var.records."
  }

  assert {
    condition = alltrue(flatten([for key, record in var.records : [
      for field in var.expected_record_fields : jsonencode(local.records[key][field]) == jsonencode(record[field])
    ]]))
    error_message = "locals.tf must pass every record field through unchanged (health_check_id included when no health_check key is used)."
  }
}

run "records_submodule_type_matches_the_pinned_fields" {
  command = plan

  module {
    source = "./modules/records"
  }

  assert {
    condition     = alltrue([for key, record in var.records : sort(keys(record)) == sort(var.expected_record_fields)])
    error_message = "modules/records var.records drifted from the pinned field list; update the root variables.tf, locals.tf, and this list together."
  }
}

run "health_checks_submodule_type_matches_the_pinned_fields" {
  command = plan

  module {
    source = "./modules/health-checks"
  }

  assert {
    condition     = alltrue([for key, check in var.health_checks : sort(keys(check)) == sort(var.expected_health_check_fields)])
    error_message = "modules/health-checks var.health_checks drifted from the pinned field list; update the root variables.tf and this list together."
  }
}
