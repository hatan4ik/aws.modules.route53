# Integration suite: real apply in the caller's own account.
#
# Requires AWS credentials and a region from the environment (for example
# AWS_PROFILE and AWS_REGION, or the OIDC role assumed by the integration
# workflow). Nothing is hard-coded: the setup module produces a random zone
# name under the reserved .invalid top-level domain, the module creates a
# public hosted zone with record sets of several types and one health check,
# the results are asserted against the real API, and everything is destroyed
# at the end of the file. A hosted zone deleted within 12 hours of creation
# is not charged; the health check is charged pro rata for the minutes it
# exists.
#
# Run: terraform init -backend=false -test-directory=tests/integration
#      terraform test -test-directory=tests/integration -filter=tests/integration/smoke.tftest.hcl

provider "aws" {}

run "setup" {
  module {
    source = "./tests/integration/setup"
  }

  variables {
    name_prefix = "route53-it"
  }
}

run "smoke" {
  variables {
    zone = {
      name    = run.setup.zone_name
      comment = "aws.modules.route53 integration suite; disposable"
      # The suite's own record sets must not block teardown.
      force_destroy = true
    }

    tags = run.setup.tags

    health_checks = {
      # TEST-NET-1 is unroutable, so probing it would only ever fail; a
      # disabled check still exercises creation, tagging, and key resolution,
      # and Route 53 treats it as healthy.
      www = { type = "TCP", ip_address = "192.0.2.10", port = 443, disabled = true }
    }

    records = {
      www   = { name = "www", type = "A", records = ["192.0.2.10", "192.0.2.11"] }
      www6  = { name = "www", type = "AAAA", records = ["2001:db8::10"] }
      app   = { name = "app", type = "CNAME", records = ["www.${run.setup.zone_name}"] }
      spf   = { name = "@", type = "TXT", ttl = 60, records = ["\"v=spf1 -all\""] }
      mail  = { name = "@", type = "MX", records = ["10 mail.${run.setup.zone_name}"] }
      caa   = { name = "@", type = "CAA", records = ["0 issue \"amazon.com\""] }
      sip   = { name = "_sip._tcp", type = "SRV", records = ["10 60 5060 sip.${run.setup.zone_name}"] }
      slack = { name = "_acme-challenge.www", type = "TXT", ttl = 30, records = ["\"token\""] }

      # Failover pair referencing the health check by key; the API rejects a
      # record whose health check ID does not exist, so acceptance proves the
      # key was resolved to a real ID.
      ha_primary   = { name = "ha", type = "A", records = ["192.0.2.10"], set_identifier = "primary", failover = { type = "PRIMARY" }, health_check = "www" }
      ha_secondary = { name = "ha", type = "A", records = ["192.0.2.11"], set_identifier = "secondary", failover = { type = "SECONDARY" } }
    }
  }

  assert {
    condition     = startswith(output.zone_id, "Z") && startswith(output.zone_arn, "arn:") && output.name == run.setup.zone_name && output.private == false
    error_message = "A public hosted zone with the fixture name must have been created."
  }

  assert {
    condition     = length(output.name_servers) == 4 && contains(output.name_servers, output.primary_name_server)
    error_message = "Route 53 must have assigned four name servers, one of them the SOA primary."
  }

  assert {
    condition     = aws_route53_zone.this[0].force_destroy == true && aws_route53_zone.this[0].tags["IntegrationTest"] == "aws.modules.route53" && aws_route53_zone.this[0].tags["Name"] == run.setup.zone_name
    error_message = "The zone must carry the fixture tags plus the module's Name tag and be force-destroyable."
  }

  assert {
    condition     = length(output.record_fqdns) == 10 && output.record_fqdns["www"] == "www.${run.setup.zone_name}" && output.record_fqdns["spf"] == run.setup.zone_name && output.record_fqdns["sip"] == "_sip._tcp.${run.setup.zone_name}"
    error_message = "Every record set must have been accepted and its FQDN resolved against the created zone."
  }

  assert {
    condition     = output.record_names["spf"] == "" && output.record_fqdns["ha_primary"] == "ha.${run.setup.zone_name}" && output.record_fqdns["ha_secondary"] == "ha.${run.setup.zone_name}"
    error_message = "The apex must be addressed by @ and both failover members must share one name."
  }

  assert {
    condition     = length(output.health_check_ids) == 1 && output.health_check_ids["www"] != null && startswith(output.health_check_arns["www"], "arn:")
    error_message = "The health check must have been created and exposed by key."
  }

  assert {
    condition     = output.dnssec_key_signing_key == null && output.query_log_id == null
    error_message = "DNSSEC and query logging must stay off unless declared."
  }
}
