mock_provider "aws" {}

variables {
  tags = { Environment = "test", Owner = "platform" }

  records = {
    www  = { name = "www", type = "A", records = ["192.0.2.10"] }
    apex = { name = "@", type = "A", alias = { name = "d111111abcdef8.cloudfront.net", zone_id = "Z2FDTNDATAQYW2" } }
  }
}

run "manages_records_in_an_existing_zone" {
  command = plan

  variables {
    zone_id = "Z0123456789ABCDEFGHIJ"
  }

  assert {
    condition     = length(aws_route53_zone.this) == 0 && length(aws_route53_zone_association.this) == 0
    error_message = "No zone may be created when zone_id names an existing one."
  }

  assert {
    condition     = output.zone_id == "Z0123456789ABCDEFGHIJ"
    error_message = "The supplied zone_id must pass through unchanged."
  }

  assert {
    condition     = output.zone_arn == null && output.name == null && output.primary_name_server == null && length(output.name_servers) == 0 && output.private == null
    error_message = "Creation-only outputs must be null or empty for an existing zone."
  }

  assert {
    condition     = length(output.record_names) == 2 && output.record_names["www"] == "www" && output.record_names["apex"] == "" && length(output.record_fqdns) == 2
    error_message = "Record outputs must be keyed by record key with @ mapped to the apex."
  }

  assert {
    condition     = length(output.health_check_ids) == 0 && length(output.health_check_arns) == 0 && output.dnssec_key_signing_key == null && output.query_log_id == null
    error_message = "Optional features must produce empty or null outputs when not declared."
  }

  assert {
    condition     = length(aws_route53_key_signing_key.this) == 0 && length(aws_route53_hosted_zone_dnssec.this) == 0 && length(aws_route53_query_log.this) == 0
    error_message = "DNSSEC and query logging resources must not exist unless declared."
  }
}

run "creates_a_public_zone" {
  command = plan

  variables {
    zone = { name = "example.com", comment = "Public zone for example.com" }
  }

  assert {
    condition     = aws_route53_zone.this[0].name == "example.com" && aws_route53_zone.this[0].comment == "Public zone for example.com" && aws_route53_zone.this[0].force_destroy == false && aws_route53_zone.this[0].delegation_set_id == null
    error_message = "The zone must use the declared name and comment and must not force-destroy by default."
  }

  assert {
    condition     = length(aws_route53_zone.this[0].vpc) == 0 && length(aws_route53_zone_association.this) == 0
    error_message = "A public zone must carry no VPC."
  }

  assert {
    condition     = aws_route53_zone.this[0].tags["Name"] == "example.com" && aws_route53_zone.this[0].tags["Owner"] == "platform"
    error_message = "Caller tags must be preserved and a Name tag added."
  }

  assert {
    condition     = output.name == "example.com" && output.private == false
    error_message = "Outputs must describe the created zone."
  }

  assert {
    condition     = length(output.record_names) == 2 && module.records.names["www"] == "www"
    error_message = "Records must be created in the new zone."
  }

  expect_failures = [check.zone_created_without_dnssec]
}

run "creates_a_public_zone_with_a_reusable_delegation_set" {
  command = plan

  variables {
    zone = { name = "example.com", delegation_set_id = "N0123456789ABCDEFGHIJ", force_destroy = false }
  }

  assert {
    condition     = aws_route53_zone.this[0].delegation_set_id == "N0123456789ABCDEFGHIJ"
    error_message = "The delegation set must pass through."
  }

  expect_failures = [check.zone_created_without_dnssec]
}

run "creates_a_private_zone_with_additional_vpc_associations" {
  command = plan

  variables {
    zone = {
      name = "example.internal"
      private = {
        vpc_id     = "vpc-0123456789abcdef0"
        vpc_region = "us-east-1"
        additional_vpcs = {
          "vpc-0123456789abcdef1" = { region = "us-west-2" }
          "vpc-0123456789abcdef2" = {}
        }
      }
    }
  }

  assert {
    condition     = length(aws_route53_zone.this[0].vpc) == 1 && tolist(aws_route53_zone.this[0].vpc)[0].vpc_id == "vpc-0123456789abcdef0" && tolist(aws_route53_zone.this[0].vpc)[0].vpc_region == "us-east-1"
    error_message = "The creation VPC must be the only VPC in the zone's inline block."
  }

  assert {
    condition     = length(aws_route53_zone_association.this) == 2 && aws_route53_zone_association.this["vpc-0123456789abcdef1"].vpc_id == "vpc-0123456789abcdef1" && aws_route53_zone_association.this["vpc-0123456789abcdef1"].vpc_region == "us-west-2" && aws_route53_zone_association.this["vpc-0123456789abcdef2"].vpc_id == "vpc-0123456789abcdef2"
    error_message = "Every additional VPC must become one standalone association keyed by VPC ID."
  }

  assert {
    condition     = aws_route53_zone.this[0].delegation_set_id == null && output.private == true && output.name == "example.internal"
    error_message = "A private zone must have no delegation set and report private = true."
  }
}
