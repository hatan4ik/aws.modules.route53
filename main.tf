# Composition root. One hosted zone per call, created here or supplied by ID;
# records and health checks live in focused submodules with their own tests.

resource "aws_route53_zone" "this" {
  count = var.zone == null ? 0 : 1

  name              = var.zone.name
  comment           = var.zone.comment
  force_destroy     = var.zone.force_destroy
  delegation_set_id = var.zone.delegation_set_id

  # A private zone must be created with a VPC. Additional VPCs are standalone
  # associations below.
  dynamic "vpc" {
    for_each = var.zone.private == null ? [] : [var.zone.private]

    content {
      vpc_id     = vpc.value.vpc_id
      vpc_region = vpc.value.vpc_region
    }
  }

  tags = merge(var.tags, { Name = var.zone.name })

  lifecycle {
    # The inline vpc block and aws_route53_zone_association manage the same
    # association list. The AWS provider documents ignoring the block once
    # associations exist as resources; without it the two fight on every plan.
    ignore_changes = [vpc]
  }
}

resource "aws_route53_zone_association" "this" {
  for_each = local.additional_vpcs

  zone_id    = aws_route53_zone.this[0].zone_id
  vpc_id     = each.key
  vpc_region = each.value.region
}

module "health_checks" {
  source = "./modules/health-checks"

  health_checks = var.health_checks
  tags          = var.tags
}

module "records" {
  source = "./modules/records"

  zone_id     = local.zone_id
  default_ttl = var.default_ttl
  records     = local.records
}

# DNSSEC: the key-signing key must be ACTIVE before signing is enabled, which
# the hosted_zone_id reference below guarantees. The caller publishes the DS
# record in the parent zone and disables signing before destroying the zone.
resource "aws_route53_key_signing_key" "this" {
  count = var.dnssec == null ? 0 : 1

  hosted_zone_id             = local.zone_id
  key_management_service_arn = var.dnssec.kms_key_arn
  name                       = var.dnssec.key_signing_key_name
  status                     = "ACTIVE"

  lifecycle {
    precondition {
      condition     = !local.zone_is_private
      error_message = "DNSSEC signing is available for public hosted zones only; remove dnssec or zone.private."
    }
  }
}

resource "aws_route53_hosted_zone_dnssec" "this" {
  count = var.dnssec == null ? 0 : 1

  hosted_zone_id = aws_route53_key_signing_key.this[0].hosted_zone_id
  signing_status = "SIGNING"
}

resource "aws_route53_query_log" "this" {
  count = var.query_logging == null ? 0 : 1

  zone_id                  = local.zone_id
  cloudwatch_log_group_arn = var.query_logging.cloudwatch_log_group_arn

  lifecycle {
    precondition {
      condition     = !local.zone_is_private
      error_message = "Query logging is available for public hosted zones only; remove query_logging or zone.private."
    }
  }
}
