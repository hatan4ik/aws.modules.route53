# Disposable prerequisites for the integration suites: a random label that
# names the hosted zone under test and, for the private-zone suite, two VPCs
# to associate it with. Everything is created and destroyed by `terraform
# test` in the caller's own account; nothing here is shared or long-lived.

data "aws_region" "current" {}

resource "random_id" "suffix" {
  byte_length = 3
}

locals {
  name = "${var.name_prefix}-${random_id.suffix.hex}"

  # A label under the reserved .invalid top-level domain (RFC 2606) can never
  # collide with a real domain and is never delegated, so a public zone with
  # this name resolves nothing outside Route 53 itself.
  zone_name = "${local.name}.integration.invalid"

  tags = merge(var.tags, {
    Name            = local.name
    IntegrationTest = "aws.modules.route53"
    Disposable      = "true"
  })
}

# Private hosted zones need DNS support and DNS hostnames enabled on every
# associated VPC. Two VPCs: the creation VPC and one additional association.
resource "aws_vpc" "this" {
  count = var.create_vpcs ? 2 : 0

  cidr_block           = cidrsubnet(var.cidr_block, 4, count.index)
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.tags, { Name = "${local.name}-${count.index}" })
}
