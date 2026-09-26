# Integration suite: a private hosted zone with VPC associations, applied for
# real in the caller's own account. The setup module creates two VPCs: the
# zone is created in the first and associated with the second through a
# standalone aws_route53_zone_association. Everything is destroyed at the end
# of the file; a hosted zone deleted within 12 hours of creation is not
# charged and VPCs are free.
#
# Run: terraform init -backend=false -test-directory=tests/integration
#      terraform test -test-directory=tests/integration -filter=tests/integration/private-zone.tftest.hcl

provider "aws" {}

run "setup" {
  module {
    source = "./tests/integration/setup"
  }

  variables {
    name_prefix = "route53-pz"
    create_vpcs = true
  }
}

run "private_zone" {
  variables {
    zone = {
      name          = run.setup.zone_name
      comment       = "aws.modules.route53 private-zone integration suite; disposable"
      force_destroy = true
      private = {
        vpc_id          = run.setup.vpc_id
        additional_vpcs = { (run.setup.additional_vpc_id) = {} }
      }
    }

    tags = run.setup.tags

    records = {
      db = { name = "db", type = "A", records = ["10.99.0.25"] }
    }
  }

  assert {
    condition     = startswith(output.zone_id, "Z") && output.private == true && output.name == run.setup.zone_name
    error_message = "A private hosted zone with the fixture name must have been created."
  }

  assert {
    condition     = contains([for vpc in aws_route53_zone.this[0].vpc : vpc.vpc_id], run.setup.vpc_id)
    error_message = "The zone must have been created in the first fixture VPC."
  }

  assert {
    condition     = length(aws_route53_zone_association.this) == 1 && aws_route53_zone_association.this[run.setup.additional_vpc_id].zone_id == output.zone_id && aws_route53_zone_association.this[run.setup.additional_vpc_id].vpc_id == run.setup.additional_vpc_id
    error_message = "The second fixture VPC must be associated through a standalone association keyed by its ID."
  }

  assert {
    condition     = output.record_fqdns["db"] == "db.${run.setup.zone_name}" && aws_route53_zone.this[0].delegation_set_id == null
    error_message = "Records must resolve against the private zone and no delegation set may be attached."
  }

  assert {
    condition     = output.dnssec_key_signing_key == null && output.query_log_id == null && length(output.health_check_ids) == 0
    error_message = "A private zone carries neither DNSSEC nor query logging, and no health checks were declared."
  }
}
