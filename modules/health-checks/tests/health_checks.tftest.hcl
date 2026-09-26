mock_provider "aws" {}

variables {
  tags = { Environment = "test" }
}

run "creates_endpoint_health_checks" {
  command = plan

  variables {
    health_checks = {
      http  = { type = "HTTP", fqdn = "app.example.com", resource_path = "/health" }
      https = { type = "HTTPS", fqdn = "app.example.com", port = 8443, resource_path = "/health", enable_sni = true, regions = ["us-east-1", "eu-west-1", "ap-southeast-1"], request_interval = 10, failure_threshold = 2, measure_latency = true, tags = { Team = "web" } }
      match = { type = "HTTPS_STR_MATCH", ip_address = "192.0.2.10", fqdn = "app.example.com", resource_path = "/ready", search_string = "ok" }
      tcp   = { type = "TCP", ip_address = "2001:db8::10", port = 5432, invert_healthcheck = true, disabled = true }
    }
  }

  assert {
    condition     = aws_route53_health_check.this["http"].type == "HTTP" && aws_route53_health_check.this["http"].fqdn == "app.example.com" && aws_route53_health_check.this["http"].resource_path == "/health" && aws_route53_health_check.this["http"].port == null
    error_message = "An HTTP check must carry its endpoint and path and leave the port to the service default."
  }

  assert {
    condition     = aws_route53_health_check.this["http"].request_interval == 30 && aws_route53_health_check.this["http"].failure_threshold == 3 && aws_route53_health_check.this["http"].measure_latency == false && aws_route53_health_check.this["http"].invert_healthcheck == false && aws_route53_health_check.this["http"].disabled == false
    error_message = "Endpoint checks must default to 30 second intervals, 3 failures, no latency measurement, not inverted, and enabled."
  }

  assert {
    condition     = aws_route53_health_check.this["https"].port == 8443 && aws_route53_health_check.this["https"].enable_sni == true && aws_route53_health_check.this["https"].regions == toset(["us-east-1", "eu-west-1", "ap-southeast-1"]) && aws_route53_health_check.this["https"].request_interval == 10 && aws_route53_health_check.this["https"].failure_threshold == 2 && aws_route53_health_check.this["https"].measure_latency == true
    error_message = "HTTPS options must pass through."
  }

  assert {
    condition     = aws_route53_health_check.this["match"].search_string == "ok" && aws_route53_health_check.this["match"].ip_address == "192.0.2.10" && aws_route53_health_check.this["match"].fqdn == "app.example.com"
    error_message = "String-match checks must carry the search string, and an IP with a Host header FQDN is allowed."
  }

  assert {
    condition     = aws_route53_health_check.this["tcp"].port == 5432 && aws_route53_health_check.this["tcp"].ip_address == "2001:db8::10" && aws_route53_health_check.this["tcp"].resource_path == null && aws_route53_health_check.this["tcp"].search_string == null && aws_route53_health_check.this["tcp"].invert_healthcheck == true && aws_route53_health_check.this["tcp"].disabled == true
    error_message = "TCP checks must carry a port and no HTTP attributes; invert and disabled must pass through."
  }

  assert {
    condition     = aws_route53_health_check.this["http"].tags["Name"] == "http" && aws_route53_health_check.this["http"].tags["Environment"] == "test" && aws_route53_health_check.this["https"].tags["Team"] == "web" && aws_route53_health_check.this["https"].tags["Environment"] == "test"
    error_message = "Module tags, per-check tags, and a Name tag equal to the key must be applied."
  }

  assert {
    condition     = length(output.ids) == 4 && length(output.arns) == 4
    error_message = "Outputs must be keyed by health check key."
  }
}

run "creates_calculated_cloudwatch_and_recovery_control_checks" {
  command = plan

  variables {
    health_checks = {
      calc = { type = "CALCULATED", child_healthchecks = ["0123abcd-4567-89ef-0123-456789abcdef", "0123abcd-4567-89ef-0123-456789abcde0"], child_health_threshold = 1 }
      alarm = {
        type                            = "CLOUDWATCH_METRIC"
        cloudwatch_alarm_name           = "orders-5xx"
        cloudwatch_alarm_region         = "us-east-1"
        insufficient_data_health_status = "LastKnownStatus"
      }
      arc = { type = "RECOVERY_CONTROL", routing_control_arn = "arn:aws:route53-recovery-control::123456789012:controlpanel/0123456789abcdef0123456789abcdef/routingcontrol/abcdef1234567890" }
    }
  }

  assert {
    condition     = aws_route53_health_check.this["calc"].child_healthchecks == toset(["0123abcd-4567-89ef-0123-456789abcdef", "0123abcd-4567-89ef-0123-456789abcde0"]) && aws_route53_health_check.this["calc"].child_health_threshold == 1
    error_message = "Calculated checks must carry their children and threshold."
  }

  assert {
    condition     = aws_route53_health_check.this["calc"].request_interval == null && aws_route53_health_check.this["calc"].fqdn == null && aws_route53_health_check.this["calc"].measure_latency == null
    error_message = "Endpoint-only attributes must not render on a calculated check."
  }

  assert {
    condition     = aws_route53_health_check.this["alarm"].cloudwatch_alarm_name == "orders-5xx" && aws_route53_health_check.this["alarm"].cloudwatch_alarm_region == "us-east-1" && aws_route53_health_check.this["alarm"].insufficient_data_health_status == "LastKnownStatus"
    error_message = "CloudWatch checks must carry the alarm and the insufficient-data status."
  }

  assert {
    condition     = aws_route53_health_check.this["arc"].routing_control_arn == "arn:aws:route53-recovery-control::123456789012:controlpanel/0123456789abcdef0123456789abcdef/routingcontrol/abcdef1234567890"
    error_message = "Recovery-control checks must carry the routing control ARN."
  }
}

run "creates_nothing_by_default" {
  command = plan

  assert {
    condition     = length(aws_route53_health_check.this) == 0 && length(output.ids) == 0
    error_message = "An empty map must create nothing."
  }
}

run "rejects_unknown_type" {
  command = plan

  variables {
    health_checks = { bad = { type = "PING", ip_address = "192.0.2.10" } }
  }

  expect_failures = [var.health_checks]
}

run "rejects_endpoint_check_without_endpoint" {
  command = plan

  variables {
    health_checks = { bad = { type = "HTTP", resource_path = "/" } }
  }

  expect_failures = [var.health_checks]
}

run "rejects_malformed_ip_address" {
  command = plan

  variables {
    health_checks = { bad = { type = "TCP", ip_address = "192.0.2.300", port = 443 } }
  }

  expect_failures = [var.health_checks]
}

run "rejects_port_out_of_range" {
  command = plan

  variables {
    health_checks = { bad = { type = "TCP", ip_address = "192.0.2.10", port = 70000 } }
  }

  expect_failures = [var.health_checks]
}

run "rejects_tcp_without_port" {
  command = plan

  variables {
    health_checks = { bad = { type = "TCP", ip_address = "192.0.2.10" } }
  }

  expect_failures = [var.health_checks]
}

run "rejects_tcp_with_resource_path" {
  command = plan

  variables {
    health_checks = { bad = { type = "TCP", ip_address = "192.0.2.10", port = 443, resource_path = "/" } }
  }

  expect_failures = [var.health_checks]
}

run "rejects_resource_path_without_leading_slash" {
  command = plan

  variables {
    health_checks = { bad = { type = "HTTP", fqdn = "app.example.com", resource_path = "health" } }
  }

  expect_failures = [var.health_checks]
}

run "rejects_string_match_without_search_string" {
  command = plan

  variables {
    health_checks = { bad = { type = "HTTP_STR_MATCH", fqdn = "app.example.com" } }
  }

  expect_failures = [var.health_checks]
}

run "rejects_search_string_on_plain_check" {
  command = plan

  variables {
    health_checks = { bad = { type = "HTTP", fqdn = "app.example.com", search_string = "ok" } }
  }

  expect_failures = [var.health_checks]
}

run "rejects_unsupported_request_interval" {
  command = plan

  variables {
    health_checks = { bad = { type = "HTTP", fqdn = "app.example.com", request_interval = 20 } }
  }

  expect_failures = [var.health_checks]
}

run "rejects_failure_threshold_out_of_range" {
  command = plan

  variables {
    health_checks = { bad = { type = "HTTP", fqdn = "app.example.com", failure_threshold = 11 } }
  }

  expect_failures = [var.health_checks]
}

run "rejects_sni_on_http_check" {
  command = plan

  variables {
    health_checks = { bad = { type = "HTTP", fqdn = "app.example.com", enable_sni = true } }
  }

  expect_failures = [var.health_checks]
}

run "rejects_unknown_checker_region" {
  command = plan

  variables {
    health_checks = { bad = { type = "HTTP", fqdn = "app.example.com", regions = ["us-east-1", "eu-west-1", "eu-central-1"] } }
  }

  expect_failures = [var.health_checks]
}

run "rejects_fewer_than_three_checker_regions" {
  command = plan

  variables {
    health_checks = { bad = { type = "HTTP", fqdn = "app.example.com", regions = ["us-east-1", "eu-west-1"] } }
  }

  expect_failures = [var.health_checks]
}

run "rejects_calculated_without_children" {
  command = plan

  variables {
    health_checks = { bad = { type = "CALCULATED", child_healthchecks = [], child_health_threshold = 1 } }
  }

  expect_failures = [var.health_checks]
}

run "rejects_calculated_threshold_above_child_count" {
  command = plan

  variables {
    health_checks = { bad = { type = "CALCULATED", child_healthchecks = ["0123abcd-4567-89ef-0123-456789abcdef"], child_health_threshold = 2 } }
  }

  expect_failures = [var.health_checks]
}

run "rejects_children_on_endpoint_check" {
  command = plan

  variables {
    health_checks = { bad = { type = "HTTP", fqdn = "app.example.com", child_healthchecks = ["0123abcd-4567-89ef-0123-456789abcdef"] } }
  }

  expect_failures = [var.health_checks]
}

run "rejects_endpoint_attributes_on_calculated_check" {
  command = plan

  variables {
    health_checks = { bad = { type = "CALCULATED", fqdn = "app.example.com", child_healthchecks = ["0123abcd-4567-89ef-0123-456789abcdef"], child_health_threshold = 1 } }
  }

  expect_failures = [var.health_checks]
}

run "rejects_cloudwatch_check_without_alarm" {
  command = plan

  variables {
    health_checks = { bad = { type = "CLOUDWATCH_METRIC", cloudwatch_alarm_name = "orders-5xx" } }
  }

  expect_failures = [var.health_checks]
}

run "rejects_unknown_insufficient_data_status" {
  command = plan

  variables {
    health_checks = { bad = { type = "CLOUDWATCH_METRIC", cloudwatch_alarm_name = "orders-5xx", cloudwatch_alarm_region = "us-east-1", insufficient_data_health_status = "Unknown" } }
  }

  expect_failures = [var.health_checks]
}

run "rejects_alarm_on_endpoint_check" {
  command = plan

  variables {
    health_checks = { bad = { type = "HTTP", fqdn = "app.example.com", cloudwatch_alarm_name = "orders-5xx", cloudwatch_alarm_region = "us-east-1" } }
  }

  expect_failures = [var.health_checks]
}

run "rejects_recovery_control_without_arn" {
  command = plan

  variables {
    health_checks = { bad = { type = "RECOVERY_CONTROL" } }
  }

  expect_failures = [var.health_checks]
}

run "rejects_malformed_routing_control_arn" {
  command = plan

  variables {
    health_checks = { bad = { type = "RECOVERY_CONTROL", routing_control_arn = "routing-control" } }
  }

  expect_failures = [var.health_checks]
}
