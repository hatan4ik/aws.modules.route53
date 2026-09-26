mock_provider "aws" {}

variables {
  zone = { name = "example.com" }

  dnssec = {
    kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/0123abcd-4567-89ef-0123-456789abcdef"
  }

  query_logging = {
    cloudwatch_log_group_arn = "arn:aws:logs:us-east-1:123456789012:log-group:/aws/route53/example.com"
  }
}

run "signs_and_logs_a_created_public_zone" {
  command = plan

  assert {
    condition     = aws_route53_key_signing_key.this[0].key_management_service_arn == "arn:aws:kms:us-east-1:123456789012:key/0123abcd-4567-89ef-0123-456789abcdef" && aws_route53_key_signing_key.this[0].name == "ksk" && aws_route53_key_signing_key.this[0].status == "ACTIVE"
    error_message = "The key-signing key must use the caller's KMS key, the default name ksk, and be active."
  }

  assert {
    condition     = aws_route53_hosted_zone_dnssec.this[0].signing_status == "SIGNING"
    error_message = "DNSSEC signing must be enabled."
  }

  assert {
    condition     = aws_route53_query_log.this[0].cloudwatch_log_group_arn == "arn:aws:logs:us-east-1:123456789012:log-group:/aws/route53/example.com"
    error_message = "Query logging must target the caller's log group."
  }

  assert {
    condition     = output.dnssec_key_signing_key != null && length(keys(output.dnssec_key_signing_key)) == 4
    error_message = "The DNSSEC output must expose ds_record, dnskey_record, key_tag, and public_key."
  }
}

run "signs_and_logs_an_existing_zone" {
  command = plan

  variables {
    zone    = null
    zone_id = "Z0123456789ABCDEFGHIJ"
    dnssec = {
      kms_key_arn          = "arn:aws:kms:us-east-1:123456789012:key/0123abcd-4567-89ef-0123-456789abcdef"
      key_signing_key_name = "example_com_2026"
    }
  }

  assert {
    condition     = aws_route53_key_signing_key.this[0].hosted_zone_id == "Z0123456789ABCDEFGHIJ" && aws_route53_key_signing_key.this[0].name == "example_com_2026" && aws_route53_hosted_zone_dnssec.this[0].hosted_zone_id == "Z0123456789ABCDEFGHIJ"
    error_message = "DNSSEC resources must attach to the supplied zone with the declared key name."
  }

  assert {
    condition     = aws_route53_query_log.this[0].zone_id == "Z0123456789ABCDEFGHIJ"
    error_message = "Query logging must attach to the supplied zone."
  }
}

run "resolves_health_check_keys_to_ids" {
  command = plan

  variables {
    health_checks = {
      primary = { type = "HTTPS", fqdn = "app.example.com", resource_path = "/health" }
      replica = { type = "TCP", ip_address = "192.0.2.20", port = 443 }
    }

    records = {
      primary   = { name = "app", type = "A", records = ["192.0.2.10"], set_identifier = "primary", failover = { type = "PRIMARY" }, health_check = "primary" }
      secondary = { name = "app", type = "A", records = ["192.0.2.20"], set_identifier = "secondary", failover = { type = "SECONDARY" }, health_check_id = "0123abcd-4567-89ef-0123-456789abcdef" }
      plain     = { name = "www", type = "A", records = ["192.0.2.30"] }
    }
  }

  assert {
    condition     = length(output.health_check_ids) == 2 && contains(keys(output.health_check_ids), "primary") && contains(keys(output.health_check_arns), "replica")
    error_message = "Health check outputs must be keyed by health check key."
  }

  assert {
    condition     = length(output.record_names) == 3 && module.records.names["primary"] == "app"
    error_message = "Records referencing health checks by key must still be created."
  }
}
