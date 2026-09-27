# Design: aws.modules.route53 v1

Status: accepted 2026-09-23. Supersedes the v0.1.x "public zone or records" design.

## Purpose

`aws.modules.route53` manages **one** Route 53 hosted zone per module call,
either created by the module (public, or private with VPC associations) or
supplied by ID, together with the things a zone owner declares against it:
record sets in every routing policy Route 53 supports, the health checks those
records reference, DNSSEC signing, and query logging. It is secure by default,
explicit by declaration, and composable: the record and health-check
submodules work standalone against any zone, and every optional feature is an
object that defaults to `null`.

The module deliberately does **not** create KMS keys, CloudWatch log groups,
VPCs, load balancers, certificates, or the parent-zone delegation (NS and DS
records). Those have separate lifecycles and owners. The module consumes their
identifiers and tells the caller exactly what to publish upstream.

## Why the v0.1.x design was replaced

| v0.1.x behaviour | Problem | v1 decision |
|---|---|---|
| `create_zone = true` created a public zone only. | Private zones, VPC associations, comments, and reusable delegation sets could not be expressed. | One `zone` object: `name`, `comment`, `force_destroy`, `delegation_set_id`, and an optional `private` block with the creation VPC and additional VPC associations. |
| `create_zone` + `zone_name` + `zone_id` were three loosely coupled inputs guarded by a `terraform_data` precondition carrier. | An extra resource in state just to validate inputs; the rule was not visible in the interface. | `zone_id` XOR `zone`, enforced by a precondition on the `zone_id` output. No carrier resource. |
| Records supported simple and alias only. | No weighted, latency, failover, geolocation, geoproximity, CIDR, or multivalue answer routing; no `set_identifier`; no health checks. | `modules/records`: a typed map covering every routing policy, with plan-time validation of the rules Route 53 enforces at apply time. |
| Every record set `allow_overwrite = true`. | Silently replaced record sets created elsewhere, including the zone's own NS and SOA. | `allow_overwrite` defaults to `false` per record; NS and SOA at the apex must opt in explicitly. |
| No health checks. | Failover and weighted policies are unsafe without them. | `modules/health-checks`: a typed map of every health check type with per-type validation, and `records[*].health_check` resolved by key in the root. |
| No DNSSEC, no query logging. | Public zones shipped unsigned and unobservable. | Opt-in `dnssec` (caller KMS key) and `query_logging` (caller log group) objects with the AWS constraints validated at plan time; an advisory check flags a public zone created without DNSSEC. |
| No tests, no examples. | Behaviour could not be pinned. | `mock_provider` contract tests for the root and both submodules; six examples validated in CI. |

## Principles and how the module applies them

- **Single responsibility.** `modules/records` owns the record-set shape and
  its routing rules; `modules/health-checks` owns health-check types; the
  root owns the zone, its VPC associations, DNSSEC, query logging, and the
  wiring between them.
- **Open/closed.** New behaviour is declared as data: a record, a health
  check, a VPC association. The module is not edited to add one.
- **Liskov substitution.** A zone supplied by `zone_id` and a zone created
  from `zone` drive identical record, health-check, DNSSEC, and query-log
  behaviour and expose the same outputs (creation-only values are `null` or
  empty for an existing zone).
- **Interface segregation.** `zone`, `private`, `dnssec`, `query_logging`,
  and every routing policy are optional objects that default to `null`. A
  minimal call is `zone_id` plus one record.
- **Dependency inversion.** The root depends on identifiers (zone ID, VPC
  IDs, KMS key ARN, log group ARN), never on how they were produced. There
  are no data sources; the ARN region rules Route 53 imposes are validated
  from the ARN text.
- **Clean, deterministic code.** Records and health checks are keyed by
  stable identifiers, every conditional attribute renders `null` when unused,
  and every validation fails at plan time with a message that names the fix.

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

Data flow: `local.zone_id` is the created zone's ID or the supplied one.
Health checks are created first because records reference their IDs; the
root resolves each `records[*].health_check` key to
`module.health_checks.ids[key]` and passes the result to `modules/records` as
`health_check_id`. DNSSEC and query logging attach to `local.zone_id`, so they
work identically for created and existing zones.

### Private zones and VPC associations

A private hosted zone must be created with at least one VPC, so
`zone.private.vpc_id` (and optional `vpc_region`) go into the zone's `vpc`
block. Every entry of `zone.private.additional_vpcs` becomes a standalone
`aws_route53_zone_association`. The zone carries
`lifecycle { ignore_changes = [vpc] }`, the pattern the AWS provider documents
for mixing the inline block with association resources; without it the two
would fight over the association list on every plan. The creation VPC is
therefore fixed at creation time: to move it, associate the new VPC as an
additional one first, then replace the zone in a separate change.

### Root interface (summary)

Exactly one of:

- `zone_id`: an existing hosted zone.
- `zone`: `{ name, comment, force_destroy, delegation_set_id, private = { vpc_id, vpc_region, additional_vpcs } }`.

Optional groups (all default to a safe value):

- `records` keyed by a stable identifier: `name`, `type`, `ttl`, `records` or
  `alias`, `set_identifier`, `health_check` (key of `health_checks`) or
  `health_check_id`, one of `weighted`, `latency`, `failover`, `geolocation`,
  `geoproximity`, `cidr`, `multivalue_answer`, and `allow_overwrite`.
- `default_ttl` for non-alias records without a `ttl`.
- `health_checks` keyed by a stable identifier, one object per check type.
- `dnssec = { kms_key_arn, key_signing_key_name }`.
- `query_logging = { cloudwatch_log_group_arn }`.
- `tags`.

Outputs: `zone_id`, `zone_arn`, `name`, `name_servers`, `primary_name_server`,
`private`, `record_fqdns`, `record_names`, `health_check_ids`,
`health_check_arns`, `dnssec_key_signing_key` (`ds_record`, `dnskey_record`,
`key_tag`, `public_key`, or `null`), and `query_log_id`.

### Lifecycle rules

- `force_destroy` defaults to `false`: a zone that still holds records is not
  destroyed. The `force_destroy_enabled` check warns when it is turned on.
- `allow_overwrite` defaults to `false` per record. NS and SOA record sets at
  the apex exist from zone creation, so managing them requires
  `allow_overwrite = true` and the module rejects the combination otherwise.
- The `vpc` block of a private zone is ignored after creation (see above).
- DNSSEC signing is enabled only after the key-signing key is `ACTIVE`; the
  caller must publish the returned `ds_record` in the parent zone to complete
  the chain of trust, and must disable signing before destroying the zone.

## Security defaults

- Nothing is overwritten: `allow_overwrite = false`, `force_destroy = false`.
- A private zone is private from creation (the VPC is in the create call),
  never a public zone later converted.
- DNSSEC requires an asymmetric `ECC_NIST_P256` `SIGN_VERIFY` KMS key in
  `us-east-1` whose key policy grants `dnssec-route53.amazonaws.com`
  `kms:DescribeKey`, `kms:GetPublicKey`, `kms:Sign`, and `kms:CreateGrant`.
  The module validates the ARN's region and documents the policy; it never
  creates or modifies the key.
- Query logging requires a CloudWatch log group in `us-east-1` with a
  resource policy that lets `route53.amazonaws.com` create streams and put
  events. The module validates the ARN's region and documents the policy; it
  never creates the log group.
- Both DNSSEC and query logging are refused on a zone the module creates as
  private, because Route 53 supports them on public zones only.
- Health checks measure only what is declared; `disabled` and
  `invert_healthcheck` default to `false`.

## Testing strategy

- Contract tests use `mock_provider` with `command = plan`; no credentials.
- `modules/records/tests` cover every routing policy and every validation via
  `expect_failures`.
- `modules/health-checks/tests` cover every check type and its validations.
- Root `tests/` cover: records in an existing zone, a created public zone, a
  private zone with the creation VPC and an additional association, DNSSEC
  and query logging, health-check key resolution, the `zone_id` XOR `zone`
  rule, and both advisory checks.
- Every example is initialised and validated in CI; examples are the
  documentation's executable form.
- Static policy: `tflint` with the AWS ruleset, Checkov, Trivy; generated
  docs are checked for drift.

## Compatibility

- Terraform `>= 1.7.0, < 2.0.0` (the consuming platform pins 1.7.5).
- AWS provider `>= 6.35.0, < 7.0.0`.
- Cross-account VPC associations (authorisation from the zone account,
  association from the VPC account), Route 53 Resolver, traffic policies,
  and CIDR collections are out of scope; the module accepts the identifiers
  they produce (`cidr.collection_id`) where a record needs one.

## Migration

`docs/UPGRADE-1.0.md` maps every v0.1.x input to its v1 equivalent, lists the
settings that preserve existing record sets, and gives `moved` blocks so a
consumer can adopt v1 without recreating the zone or its records.
