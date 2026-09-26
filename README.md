# aws.modules.route53

Manages one Amazon Route 53 hosted zone per module call, created here (public, or private with VPC associations) or supplied by ID, together with everything a zone owner declares against it: record sets in every routing policy Route 53 supports, the health checks those records reference, DNSSEC signing, and query logging. It is secure by default and explicit by declaration: nothing is overwritten, nothing is force-destroyed, and every optional feature is an object that defaults to `null`. The record and health-check submodules work standalone against any zone, and the module performs no data-source reads. Requires Terraform >= 1.7 and the AWS provider >= 6.35, < 7.

## Why this module

What you get without setting anything:

- Nothing is replaced silently. `allow_overwrite` is `false` on every record set, so a record created elsewhere fails the apply instead of being taken over; the apex NS and SOA sets that Route 53 creates with the zone cannot be managed without opting in.
- Nothing is destroyed with its records. `force_destroy` is `false`; a zone that still holds record sets is not deleted, and the `force_destroy_enabled` check warns while it is on.
- Private zones are private from creation. The creation VPC is part of the create call, so a zone is never public first and converted later; further VPCs are standalone associations you can add and remove one at a time.
- Plan-time validation of every rule Route 53 otherwise enforces at apply time: exactly one of `records` or `alias`, at most one routing policy, `set_identifier` with a policy and never without, health checks only where they take effect, no CNAME at the apex, one value per CNAME, per-type health-check attributes, and the `us-east-1` constraint on DNSSEC keys and query-log groups.
- Health checks referenced by key. `records[*].health_check` names an entry of `health_checks` and the module resolves it to the ID; a missing key fails the plan.
- DNSSEC and query logging as declarations: a KMS key ARN and a log group ARN. The module validates their region, refuses them on private zones, and returns the DS record you publish upstream.
- Identical outputs for a created and an existing zone, so downstream wiring does not care which one you used.

## Quick start

```hcl
module "example_com" {
  source = "git::https://github.com/hatan4ik/aws.modules.route53.git?ref=<commit-sha>" # v1.0.0

  zone = { name = "example.com" }

  records = {
    apex = { name = "@", type = "A", alias = { name = "d111111abcdef8.cloudfront.net", zone_id = "Z2FDTNDATAQYW2" } }
    www  = { name = "www", type = "CNAME", records = ["d111111abcdef8.cloudfront.net"] }
    mail = { name = "@", type = "MX", records = ["10 mail.example.com."] }
    spf  = { name = "@", type = "TXT", records = ["\"v=spf1 include:_spf.example.net -all\""] }
  }

  tags = { Environment = "prod", Owner = "platform" }
}
```

This creates the public hosted zone `example.com` tagged `Name = example.com`, four record sets in it (the non-alias ones with a 300-second TTL), and nothing else. Publish `module.example_com.name_servers` at the registrar to delegate. The `zone_created_without_dnssec` check warns on every plan until you add `dnssec`; it never blocks.

## Architecture

```text
root (one hosted zone)
├── aws_route53_zone.this[0]                 created when zone != null; public, or private with the creation VPC
├── aws_route53_zone_association.this[*]     one per zone.private.additional_vpcs entry
├── modules/health-checks                    aws_route53_health_check.this[key]
├── modules/records                          aws_route53_record.this[key], health_check keys resolved to IDs
├── aws_route53_key_signing_key.this[0]      dnssec != null: KSK backed by the caller's us-east-1 KMS key
├── aws_route53_hosted_zone_dnssec.this[0]   dnssec != null: signing enabled once the KSK is active
└── aws_route53_query_log.this[0]            query_logging != null: caller's us-east-1 log group
```

`local.zone_id` is the created zone's ID or the supplied one. Health checks are created first because records reference their IDs; the root resolves each `records[*].health_check` key to `module.health_checks.ids[key]` and hands the result to `modules/records` as `health_check_id`. DNSSEC and query logging attach to `local.zone_id`, so they behave identically for created and existing zones.

| Concern | Managed by default | Bring your own |
| --- | --- | --- |
| Hosted zone | Created from `zone = { name, comment, force_destroy, delegation_set_id, private }`. | `zone_id` names an existing zone; creation-only outputs (`zone_arn`, `name`, `name_servers`, `primary_name_server`, `private`) are `null` or empty. |
| VPC associations | `zone.private.vpc_id` at creation, `zone.private.additional_vpcs` as standalone associations. | Cross-account associations (authorisation in the zone account, association from the VPC account) are declared outside the module. |
| Health checks | `health_checks` keyed by identifier, referenced from records by key through `health_check`. | `records[*].health_check_id` references a check created elsewhere. |
| DNSSEC key-signing key | Created from `dnssec = { kms_key_arn, key_signing_key_name }` and signing enabled. | The KMS key is always yours; the module never creates or modifies it. |
| Query logging | `query_logging = { cloudwatch_log_group_arn }`. | The log group and its resource policy are always yours. |

## Usage patterns

| Example | What it shows |
| --- | --- |
| [`examples/minimal`](examples/minimal) | Records in an existing zone: the smallest working call. |
| [`examples/public-zone`](examples/public-zone) | A public zone with apex, `www`, and CAA records, and the name servers to delegate. |
| [`examples/private-zone`](examples/private-zone) | A private zone created in one VPC and associated with further VPCs. |
| [`examples/routing-policies`](examples/routing-policies) | Weighted, failover, latency, and geolocation record sets with health checks referenced by key. |
| [`examples/dnssec-and-query-logging`](examples/dnssec-and-query-logging) | A signed, logged public zone, with the KMS key policy and log resource policy Route 53 requires. |
| [`examples/multiple-zones`](examples/multiple-zones) | `for_each` over a map of zones: one module call per zone. |

## Security model

Zone

- `force_destroy = false`: destroying the module fails while the zone still holds record sets you did not declare. Turn it on only for disposable zones; the `force_destroy_enabled` check warns while it is set.
- A private zone is created with its VPC and stays private. `delegation_set_id` is rejected on a private zone, and DNSSEC and query logging are refused on a zone the module created as private because Route 53 supports them on public zones only. An existing zone is not inspected, so those two features are your responsibility to apply to a public zone.
- The module adds only a `Name` tag and never overrides caller tags.

Records

- `allow_overwrite = false` per record. Managing the apex NS or SOA set requires `allow_overwrite = true` explicitly, and the module rejects the combination otherwise.
- A health check is accepted only with a routing policy, because Route 53 ignores it on a simple record; the module refuses to let you believe a check applies where it does not.
- TXT and SPF values are passed verbatim with the double quotes you supply, so what is in the plan is what Route 53 stores.

DNSSEC

- `dnssec.kms_key_arn` must be a key ARN (not an alias) in `us-east-1`, backing an asymmetric `ECC_NIST_P256` `SIGN_VERIFY` customer managed key whose policy grants `dnssec-route53.amazonaws.com` `kms:DescribeKey`, `kms:GetPublicKey`, `kms:Sign`, and `kms:CreateGrant`. The module validates the ARN and documents the policy in [`examples/dnssec-and-query-logging`](examples/dnssec-and-query-logging); it never touches the key.
- Signing is enabled only after the key-signing key is `ACTIVE`. The chain of trust is complete once you publish output `dnssec_key_signing_key.ds_record` in the parent zone.

Query logging

- `query_logging.cloudwatch_log_group_arn` must be a log group in `us-east-1` whose resource policy lets `route53.amazonaws.com` call `logs:CreateLogStream` and `logs:PutLogEvents`. The module validates the ARN; the log group, its retention, encryption, and policy are yours.

Not created here

- KMS keys, CloudWatch log groups, VPCs, load balancers, certificates, CIDR collections, reusable delegation sets, and the parent-zone delegation (NS and DS records). They have separate lifecycles and owners; the module consumes their identifiers and tells you what to publish upstream.

## Lifecycle notes

- Exactly one of `zone_id` or `zone` must be set; the precondition on output `zone_id` names the rule. Switching from one to the other is a replacement of everything below the zone, so choose at the start.
- The creation VPC of a private zone is fixed. The zone ignores changes to its `vpc` block after creation (the AWS provider's documented pattern for mixing the inline block with `aws_route53_zone_association`), so to move a zone to a new VPC, associate the new VPC as an additional one first and replace the zone in a separate change.
- Health checks are created before records, and a record that references a check by key waits for it. Removing a check that a record still references fails at plan time.
- Disable DNSSEC before destroying a signed zone: remove `dnssec`, apply (signing is disabled and the key-signing key deactivated and deleted), then remove the zone. Route 53 refuses to delete a signed zone. Removing the DS record from the parent zone first avoids validation failures for resolvers during the change.
- Two `check` blocks warn on every plan and apply but never block: `force_destroy_enabled` and `zone_created_without_dnssec`.
- Record keys are stable identifiers: renaming a key replaces that record set only. Changing `name`, `type`, or `set_identifier` replaces the record set; changing values, TTL, weight, or health check updates it in place.

## Testing

Two layers, deliberately separate:

- **Contract tests** (`tests/`, `modules/*/tests/`, run by `make test` and by CI) use `mock_provider`: no credentials, nothing created, placeholder identifiers such as the AWS documentation account `123456789012` and zone `Z0123456789ABCDEFGHIJ`. They pin the module's interface, validations, rendered arguments, and defaults, and run identically for everyone.
- **Integration suites** (`tests/integration/`, run by `make integration-smoke` and `make integration-private-zone`, or the dispatch-only `integration` workflow) apply the module for real in **your** account with **your** credentials and region from the environment, against a disposable zone named `<random>.integration.invalid` and, for the private-zone suite, two VPCs the suite creates and destroys itself. `smoke` proves a public zone, record sets of every common type, and a health check are accepted by the AWS APIs; `private-zone` proves creation in one VPC and association with a second. See [tests/integration/README.md](tests/integration/README.md) for permissions, cost, and the GitHub environment contract.

## Design principles

- Single responsibility. `modules/records` owns the record-set shape and its routing rules; `modules/health-checks` owns the health-check types; the root owns the zone, its VPC associations, DNSSEC, query logging, and the wiring between them.
- Open/closed. New behaviour is declared as data: a record, a health check, a VPC association. The module is not edited to add one.
- Liskov substitution. A zone supplied by `zone_id` and a zone created from `zone` drive identical record, health-check, DNSSEC, and query-log behaviour and expose the same outputs; only the creation-only values differ (`null` or empty for an existing zone).
- Interface segregation. `zone`, `zone.private`, `dnssec`, `query_logging`, and every routing policy are optional objects that default to `null`. A minimal call is `zone_id` plus one record.
- Dependency inversion. The root depends on identifiers (zone ID, VPC IDs, KMS key ARN, log group ARN), never on how they were produced. There are no data sources; the region rules Route 53 imposes are validated from the ARN text.

The full rationale, including why the v0.1.x design was replaced, is in [docs/DESIGN.md](docs/DESIGN.md).

## Compatibility and scope

- Terraform `>= 1.7.0, < 2.0.0`. AWS provider `>= 6.35.0, < 7.0.0`.
- Route 53 hosted zones, record sets (A, AAAA, CAA, CNAME, DS, HTTPS, MX, NAPTR, NS, PTR, SOA, SPF, SRV, SSHFP, SVCB, TLSA, TXT), every routing policy (weighted, latency, failover, geolocation, geoproximity, CIDR, multivalue answer), every health check type (HTTP, HTTPS, string match, TCP, calculated, CloudWatch metric, recovery control), DNSSEC, and query logging.
- Out of scope: Route 53 Resolver, traffic policies, CIDR collections (a record accepts `cidr.collection_id`), domain registration, and cross-account VPC associations. They will arrive, if at all, as separate modules or optional inputs and will not break the v1 interface.

## Versioning and releases

Releases follow semantic versioning: incompatible interface changes bump the major version, new optional inputs and outputs bump the minor version, fixes bump the patch version. Every release is a signed annotated tag `vX.Y.Z`.

Pin the full commit SHA of the release tag and record the tag in a comment, so the source cannot move under you:

```hcl
module "example_com" {
  source = "git::https://github.com/hatan4ik/aws.modules.route53.git?ref=<commit-sha>" # v1.0.0
}

module "records" {
  source = "git::https://github.com/hatan4ik/aws.modules.route53.git//modules/records?ref=<commit-sha>" # v1.0.0
}
```

The `module-release` workflow publishes an immutable GitHub release only from a GitHub-verified, signed, annotated semantic-version tag that points at the merged `main` revision; lightweight or unsigned tags are rejected before anything is published. With a GitHub-associated GPG or SSH signing key configured:

```bash
git fetch origin
git tag -s vX.Y.Z <commit> -m "vX.Y.Z"
git push origin vX.Y.Z
gh workflow run module-release.yml --ref vX.Y.Z -f release_tag=vX.Y.Z
```

Dispatch from the tag, never from `main`: the workflow verifies that the tag points at the revision it checked out, and a maintenance release for an older line (for example a 0.1.x fix after 1.0.0 landed on `main`) is cut from that line's commit.

Upgrading from 0.1.x: read [docs/UPGRADE-1.0.md](docs/UPGRADE-1.0.md) for the input mapping, the settings that preserve existing record sets, and ready-to-paste `moved` blocks. All changes are listed in [CHANGELOG.md](CHANGELOG.md).

## Contributing

Development setup, the local quality gate, the test-first workflow, the integration suites, and the release process are described in [CONTRIBUTING.md](CONTRIBUTING.md). Security reports go through [SECURITY.md](SECURITY.md).

## License

Apache-2.0. See [LICENSE](LICENSE).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0, < 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.35.0, < 7.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.35.0, < 7.0.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_health_checks"></a> [health\_checks](#module\_health\_checks) | ./modules/health-checks | n/a |
| <a name="module_records"></a> [records](#module\_records) | ./modules/records | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_route53_hosted_zone_dnssec.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_hosted_zone_dnssec) | resource |
| [aws_route53_key_signing_key.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_key_signing_key) | resource |
| [aws_route53_query_log.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_query_log) | resource |
| [aws_route53_zone.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone) | resource |
| [aws_route53_zone_association.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone_association) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_default_ttl"></a> [default\_ttl](#input\_default\_ttl) | TTL in seconds applied to non-alias records that declare no ttl. | `number` | `300` | no |
| <a name="input_dnssec"></a> [dnssec](#input\_dnssec) | Enable DNSSEC signing with a key-signing key backed by kms\_key\_arn: an asymmetric ECC\_NIST\_P256 SIGN\_VERIFY customer managed key in us-east-1 whose key policy grants dnssec-route53.amazonaws.com kms:DescribeKey, kms:GetPublicKey, kms:Sign, and kms:CreateGrant. Publish output dnssec\_key\_signing\_key.ds\_record in the parent zone afterwards. Public zones only. | <pre>object({<br/>    kms_key_arn          = string<br/>    key_signing_key_name = optional(string, "ksk")<br/>  })</pre> | `null` | no |
| <a name="input_health_checks"></a> [health\_checks](#input\_health\_checks) | Health checks keyed by a stable identifier; see modules/health-checks for the per-type rules. Records reference them by key through health\_check. | <pre>map(object({<br/>    type                            = string<br/>    fqdn                            = optional(string)<br/>    ip_address                      = optional(string)<br/>    port                            = optional(number)<br/>    resource_path                   = optional(string)<br/>    search_string                   = optional(string)<br/>    request_interval                = optional(number, 30)<br/>    failure_threshold               = optional(number, 3)<br/>    measure_latency                 = optional(bool, false)<br/>    invert_healthcheck              = optional(bool, false)<br/>    disabled                        = optional(bool, false)<br/>    enable_sni                      = optional(bool)<br/>    regions                         = optional(set(string))<br/>    child_healthchecks              = optional(set(string))<br/>    child_health_threshold          = optional(number)<br/>    cloudwatch_alarm_name           = optional(string)<br/>    cloudwatch_alarm_region         = optional(string)<br/>    insufficient_data_health_status = optional(string)<br/>    routing_control_arn             = optional(string)<br/>    tags                            = optional(map(string), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_query_logging"></a> [query\_logging](#input\_query\_logging) | Send DNS query logs to an existing CloudWatch log group in us-east-1 whose resource policy lets route53.amazonaws.com call logs:CreateLogStream and logs:PutLogEvents. The module does not create the log group. Public zones only. | <pre>object({<br/>    cloudwatch_log_group_arn = string<br/>  })</pre> | `null` | no |
| <a name="input_records"></a> [records](#input\_records) | Record sets keyed by a stable identifier; see modules/records for the routing rules. health\_check names a key of health\_checks and is resolved to its ID; health\_check\_id references a check created elsewhere. Either requires a routing policy. | <pre>map(object({<br/>    name    = string<br/>    type    = string<br/>    ttl     = optional(number)<br/>    records = optional(set(string))<br/>    alias = optional(object({<br/>      name                   = string<br/>      zone_id                = string<br/>      evaluate_target_health = optional(bool, false)<br/>    }))<br/>    set_identifier  = optional(string)<br/>    health_check    = optional(string)<br/>    health_check_id = optional(string)<br/>    weighted = optional(object({<br/>      weight = number<br/>    }))<br/>    latency = optional(object({<br/>      region = string<br/>    }))<br/>    failover = optional(object({<br/>      type = string<br/>    }))<br/>    geolocation = optional(object({<br/>      continent   = optional(string)<br/>      country     = optional(string)<br/>      subdivision = optional(string)<br/>    }))<br/>    geoproximity = optional(object({<br/>      aws_region       = optional(string)<br/>      local_zone_group = optional(string)<br/>      bias             = optional(number)<br/>      coordinates = optional(object({<br/>        latitude  = string<br/>        longitude = string<br/>      }))<br/>    }))<br/>    cidr = optional(object({<br/>      collection_id = string<br/>      location_name = string<br/>    }))<br/>    multivalue_answer = optional(bool, false)<br/>    allow_overwrite   = optional(bool, false)<br/>  }))</pre> | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the hosted zone and every health check. The module adds a Name tag and never overrides caller tags. | `map(string)` | `{}` | no |
| <a name="input_zone"></a> [zone](#input\_zone) | Hosted zone to create. Public unless private is set; private.vpc\_id is the VPC the zone is created in and private.additional\_vpcs (keyed by VPC ID, each with an optional region) become standalone associations. force\_destroy deletes record sets on destroy. delegation\_set\_id applies to public zones only. Exactly one of zone\_id or zone must be set. | <pre>object({<br/>    name              = string<br/>    comment           = optional(string)<br/>    force_destroy     = optional(bool, false)<br/>    delegation_set_id = optional(string)<br/>    private = optional(object({<br/>      vpc_id     = string<br/>      vpc_region = optional(string)<br/>      additional_vpcs = optional(map(object({<br/>        region = optional(string)<br/>      })), {})<br/>    }))<br/>  })</pre> | `null` | no |
| <a name="input_zone_id"></a> [zone\_id](#input\_zone\_id) | ID of an existing hosted zone to manage records, health checks, DNSSEC, and query logging in. Exactly one of zone\_id or zone must be set. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_dnssec_key_signing_key"></a> [dnssec\_key\_signing\_key](#output\_dnssec\_key\_signing\_key) | Key-signing key details when dnssec is set, or null: ds\_record to publish in the parent zone, dnskey\_record, key\_tag, and public\_key. |
| <a name="output_health_check_arns"></a> [health\_check\_arns](#output\_health\_check\_arns) | Health check ARNs keyed by health check key. |
| <a name="output_health_check_ids"></a> [health\_check\_ids](#output\_health\_check\_ids) | Health check IDs keyed by health check key. |
| <a name="output_name"></a> [name](#output\_name) | Name of the created hosted zone, or null for an existing zone. |
| <a name="output_name_servers"></a> [name\_servers](#output\_name\_servers) | Name servers of the created hosted zone to delegate to from the parent zone; empty for an existing zone. |
| <a name="output_primary_name_server"></a> [primary\_name\_server](#output\_primary\_name\_server) | Primary name server of the created hosted zone (the SOA MNAME), or null for an existing zone. |
| <a name="output_private"></a> [private](#output\_private) | Whether the created hosted zone is private, or null for an existing zone (the module does not look it up). |
| <a name="output_query_log_id"></a> [query\_log\_id](#output\_query\_log\_id) | ID of the query logging configuration when query\_logging is set, or null. |
| <a name="output_record_fqdns"></a> [record\_fqdns](#output\_record\_fqdns) | Fully qualified record names keyed by record key. |
| <a name="output_record_names"></a> [record\_names](#output\_record\_names) | Record names as declared (empty string for the apex) keyed by record key. |
| <a name="output_zone_arn"></a> [zone\_arn](#output\_zone\_arn) | ARN of the created hosted zone, or null for an existing zone. |
| <a name="output_zone_id"></a> [zone\_id](#output\_zone\_id) | ID of the hosted zone, created or supplied. |
<!-- END_TF_DOCS -->
