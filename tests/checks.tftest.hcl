mock_provider "aws" {}

run "warns_when_force_destroy_is_enabled" {
  command = plan

  variables {
    zone = { name = "example.internal", force_destroy = true, private = { vpc_id = "vpc-0123456789abcdef0" } }
  }

  assert {
    condition     = aws_route53_zone.this[0].force_destroy == true
    error_message = "force_destroy must pass through when the caller opts in."
  }

  expect_failures = [check.force_destroy_enabled]
}

run "warns_when_a_public_zone_is_created_without_dnssec" {
  command = plan

  variables {
    zone = { name = "example.com" }
  }

  expect_failures = [check.zone_created_without_dnssec]
}

run "does_not_warn_for_a_signed_public_zone" {
  command = plan

  variables {
    zone   = { name = "example.com" }
    dnssec = { kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/0123abcd-4567-89ef-0123-456789abcdef" }
  }

  assert {
    condition     = length(aws_route53_hosted_zone_dnssec.this) == 1
    error_message = "A signed public zone must not trigger any advisory check."
  }
}

run "does_not_warn_for_a_private_zone_without_dnssec" {
  command = plan

  variables {
    zone = { name = "example.internal", private = { vpc_id = "vpc-0123456789abcdef0" } }
  }

  assert {
    condition     = length(aws_route53_hosted_zone_dnssec.this) == 0
    error_message = "A private zone cannot be signed and must not trigger the DNSSEC check."
  }
}

run "does_not_warn_for_an_existing_zone" {
  command = plan

  variables {
    zone_id = "Z0123456789ABCDEFGHIJ"
  }

  assert {
    condition     = length(aws_route53_zone.this) == 0
    error_message = "An existing zone must not trigger any advisory check."
  }
}
