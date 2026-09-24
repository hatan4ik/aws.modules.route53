mock_provider "aws" {}

variables {
  zone = { name = "example.internal", private = { vpc_id = "vpc-0123456789abcdef0" } }
}

run "rejects_zone_id_together_with_zone" {
  command = plan

  variables {
    zone_id = "Z0123456789ABCDEFGHIJ"
  }

  expect_failures = [output.zone_id]
}

run "rejects_neither_zone_id_nor_zone" {
  command = plan

  variables {
    zone = null
  }

  expect_failures = [output.zone_id]
}

run "rejects_malformed_zone_id" {
  command = plan

  variables {
    zone    = null
    zone_id = "example.com"
  }

  expect_failures = [var.zone_id]
}

run "rejects_malformed_zone_name" {
  command = plan

  variables {
    zone = { name = "Example.com", private = { vpc_id = "vpc-0123456789abcdef0" } }
  }

  expect_failures = [var.zone]
}

run "rejects_delegation_set_on_private_zone" {
  command = plan

  variables {
    zone = { name = "example.internal", delegation_set_id = "N0123456789ABCDEFGHIJ", private = { vpc_id = "vpc-0123456789abcdef0" } }
  }

  expect_failures = [var.zone]
}

run "rejects_malformed_delegation_set_id" {
  command = plan

  variables {
    zone = { name = "example.com", delegation_set_id = "delegation-set" }
  }

  expect_failures = [var.zone]
}

run "rejects_malformed_vpc_id" {
  command = plan

  variables {
    zone = { name = "example.internal", private = { vpc_id = "my-vpc" } }
  }

  expect_failures = [var.zone]
}

run "rejects_additional_vpc_equal_to_creation_vpc" {
  command = plan

  variables {
    zone = { name = "example.internal", private = { vpc_id = "vpc-0123456789abcdef0", additional_vpcs = { "vpc-0123456789abcdef0" = {} } } }
  }

  expect_failures = [var.zone]
}

run "rejects_malformed_vpc_region" {
  command = plan

  variables {
    zone = { name = "example.internal", private = { vpc_id = "vpc-0123456789abcdef0", vpc_region = "virginia" } }
  }

  expect_failures = [var.zone]
}

run "rejects_unknown_health_check_key" {
  command = plan

  variables {
    records = {
      app = { name = "app", type = "A", records = ["192.0.2.10"], set_identifier = "primary", failover = { type = "PRIMARY" }, health_check = "missing" }
    }
  }

  expect_failures = [output.health_check_ids]
}

run "rejects_health_check_key_together_with_health_check_id" {
  command = plan

  variables {
    health_checks = { primary = { type = "TCP", ip_address = "192.0.2.10", port = 443 } }
    records = {
      app = { name = "app", type = "A", records = ["192.0.2.10"], set_identifier = "primary", failover = { type = "PRIMARY" }, health_check = "primary", health_check_id = "0123abcd-4567-89ef-0123-456789abcdef" }
    }
  }

  expect_failures = [var.records]
}

run "rejects_health_check_key_on_simple_record" {
  command = plan

  variables {
    health_checks = { primary = { type = "TCP", ip_address = "192.0.2.10", port = 443 } }
    records = {
      app = { name = "app", type = "A", records = ["192.0.2.10"], health_check = "primary" }
    }
  }

  expect_failures = [var.records]
}

run "rejects_dnssec_on_private_zone" {
  command = plan

  variables {
    dnssec = { kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/0123abcd-4567-89ef-0123-456789abcdef" }
  }

  expect_failures = [aws_route53_key_signing_key.this]
}

run "rejects_query_logging_on_private_zone" {
  command = plan

  variables {
    query_logging = { cloudwatch_log_group_arn = "arn:aws:logs:us-east-1:123456789012:log-group:/aws/route53/example.internal" }
  }

  expect_failures = [aws_route53_query_log.this]
}

run "rejects_kms_key_outside_us_east_1" {
  command = plan

  variables {
    zone    = null
    zone_id = "Z0123456789ABCDEFGHIJ"
    dnssec  = { kms_key_arn = "arn:aws:kms:eu-west-1:123456789012:key/0123abcd-4567-89ef-0123-456789abcdef" }
  }

  expect_failures = [var.dnssec]
}

run "rejects_kms_alias_arn" {
  command = plan

  variables {
    zone    = null
    zone_id = "Z0123456789ABCDEFGHIJ"
    dnssec  = { kms_key_arn = "arn:aws:kms:us-east-1:123456789012:alias/dnssec" }
  }

  expect_failures = [var.dnssec]
}

run "rejects_malformed_key_signing_key_name" {
  command = plan

  variables {
    zone    = null
    zone_id = "Z0123456789ABCDEFGHIJ"
    dnssec  = { kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/0123abcd-4567-89ef-0123-456789abcdef", key_signing_key_name = "example.com" }
  }

  expect_failures = [var.dnssec]
}

run "rejects_log_group_outside_us_east_1" {
  command = plan

  variables {
    zone          = null
    zone_id       = "Z0123456789ABCDEFGHIJ"
    query_logging = { cloudwatch_log_group_arn = "arn:aws:logs:eu-west-1:123456789012:log-group:/aws/route53/example.com" }
  }

  expect_failures = [var.query_logging]
}

run "rejects_default_ttl_out_of_range" {
  command = plan

  variables {
    default_ttl = 2147483648
  }

  expect_failures = [var.default_ttl]
}
