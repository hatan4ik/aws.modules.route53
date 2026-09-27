# Changelog

All notable changes to this module are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). Consumers pin the commit SHA of a release tag; see [Versioning and releases](README.md#versioning-and-releases).

## [Unreleased]

## [1.0.0] - 2026-09-24

Breaking release. One module call now manages one hosted zone, created or existing, with typed record sets, health checks, DNSSEC, and query logging. [docs/UPGRADE-1.0.md](docs/UPGRADE-1.0.md) maps every 0.1.x input to its replacement, explains the one behavioural change (`allow_overwrite`), and gives ready-to-paste `moved` blocks.

### Added

- Submodules `records` and `health-checks`, each with its own tests and usable standalone from a Git source against any hosted zone.
- `zone` object to create a hosted zone with `comment`, `force_destroy`, `delegation_set_id`, and `private = { vpc_id, vpc_region, additional_vpcs }`. Private zones are created in their first VPC and associated with every additional VPC through a standalone `aws_route53_zone_association`.
- Every Route 53 routing policy on record sets: `weighted`, `latency`, `failover`, `geolocation`, `geoproximity` (region, local zone group, or coordinates with bias), `cidr`, and `multivalue_answer`, each with `set_identifier`, plus `health_check` (a key of `health_checks`) or `health_check_id`, `allow_overwrite`, and `default_ttl`.
- Record types `CAA`, `DS`, `HTTPS`, `NAPTR`, `NS`, `PTR`, `SOA`, `SPF`, `SRV`, `SSHFP`, `SVCB`, and `TLSA` validated alongside `A`, `AAAA`, `CNAME`, `MX`, and `TXT`.
- `health_checks` map covering `HTTP`, `HTTPS`, `HTTP_STR_MATCH`, `HTTPS_STR_MATCH`, `TCP`, `CALCULATED`, `CLOUDWATCH_METRIC`, and `RECOVERY_CONTROL` checks with per-type validation of endpoint, string-match, region, child, alarm, and routing-control attributes.
- `dnssec = { kms_key_arn, key_signing_key_name }` creating an active key-signing key and enabling signing; output `dnssec_key_signing_key` exposes `ds_record`, `dnskey_record`, `key_tag`, and `public_key`.
- `query_logging = { cloudwatch_log_group_arn }` creating the query logging configuration; output `query_log_id`.
- Plan-time validation of zone names, hosted zone and delegation set IDs, VPC IDs and regions, the `us-east-1` region of DNSSEC keys and query-log groups, and every record and health-check rule Route 53 enforces at apply time; preconditions refusing DNSSEC and query logging on a private zone and an unknown `health_check` key.
- Advisory `check` blocks that warn without blocking: `force_destroy_enabled` and `zone_created_without_dnssec`.
- Outputs `zone_arn`, `name`, `primary_name_server`, `private`, `record_names`, `health_check_ids`, `health_check_arns`, `dnssec_key_signing_key`, and `query_log_id`.
- Six examples (`minimal`, `public-zone`, `private-zone`, `routing-policies`, `dnssec-and-query-logging`, `multiple-zones`) validated in CI.
- Credential-driven integration suites `smoke` and `private-zone` in `tests/integration/` with disposable fixtures, the IAM policies they need, the dispatch-only `integration` workflow, and `make integration-*` targets.
- `docs/DESIGN.md`, `docs/UPGRADE-1.0.md`, submodule READMEs, `CONTRIBUTING.md`, `SECURITY.md`, and `LICENSE`.
- Repository standards: Makefile quality gate, pre-commit configuration, tflint and terraform-docs configuration, Checkov and Trivy configuration, issue and pull request templates, Dependabot, CODEOWNERS, and the `terraform-quality` matrix over the root, both submodules, and every example.

### Changed

- **Breaking:** `create_zone`, `zone_name`, and `force_destroy` are replaced by the `zone` object. Exactly one of `zone_id` or `zone` must be set.
- **Breaking:** record sets are created by `modules/records`; their state address moves from `aws_route53_record.this[<key>]` to `module.records.aws_route53_record.this[<key>]`.
- **Breaking:** `allow_overwrite` defaults to `false` per record (was always `true`). Managing the apex NS or SOA set requires `allow_overwrite = true` explicitly.
- **Breaking:** a `health_check_id` on a record without a routing policy, a CNAME at the apex, a CNAME with several values, `ttl` on an alias record, and a `set_identifier` without a policy are rejected at plan time instead of failing or being ignored at apply time.
- `tags` are applied to every health check as well as the zone, and the module adds `Name = <zone name>` to the zone.
- The AWS provider constraint is `>= 6.35.0, < 7.0.0` (was `>= 6.0, < 7.0`).

### Removed

- **Breaking:** `terraform_data.input_contract`. The `zone_id` XOR `zone` rule is a precondition on output `zone_id`.
- **Breaking:** the implicit `tolist()` conversion of record values; `records` is a set of strings end to end.

### Fixed

- Record sets created elsewhere, including a zone's own NS and SOA sets, were silently replaced on every apply. Nothing is overwritten unless declared.
- A private hosted zone, a zone comment, and a reusable delegation set could not be expressed at all.

## [0.1.2] - 2026-09-22

### Changed

- The provider lock file carries checksums for every supported runner platform, and CI validates modules that declare provider aliases.

## [0.1.1] - 2026-09-22

### Added

- Generated module reference in the README.

## [0.1.0] - 2026-09-22

### Added

- Versioned module creating a public hosted zone (`create_zone` and `zone_name`) or managing simple and alias record sets in an existing zone (`zone_id`), with `force_destroy`, and `zone_id`, `name_servers`, and `record_fqdns` outputs.

[Unreleased]: https://github.com/hatan4ik/aws.modules.route53/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/hatan4ik/aws.modules.route53/compare/v0.1.2...v1.0.0
[0.1.2]: https://github.com/hatan4ik/aws.modules.route53/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/hatan4ik/aws.modules.route53/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/hatan4ik/aws.modules.route53/releases/tag/v0.1.0
