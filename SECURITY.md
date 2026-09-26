# Security policy

## Supported versions

| Version | Supported |
| --- | --- |
| 1.x | Yes. Security fixes and functional fixes on the latest minor release. |
| 0.1.x | Security fixes only, until 2026-12-31. Upgrade with [docs/UPGRADE-1.0.md](docs/UPGRADE-1.0.md). |
| Unreleased `main` | Not supported for production use. |

## Reporting a vulnerability

Use GitHub private vulnerability reporting on this repository: open the Security tab and choose "Report a vulnerability". Do not open a public issue, pull request, or discussion for a security problem.

Include the module version or commit SHA, the inputs that reproduce the problem, the resulting plan, and the impact you see.

## What counts

- A module default that weakens security: a record set overwritten without `allow_overwrite`, a zone destroyed with its records without `force_destroy`, a private zone reachable from the public internet, DNSSEC signing enabled with an unvalidated key, or query logs sent somewhere the caller did not name.
- A validation bypass: an input the module claims to reject at plan time but that reaches the provider, for example a CNAME at the apex, a health check on a simple record, or a DNSSEC key outside `us-east-1`.
- A caller-supplied hosted zone, KMS key, log group, or VPC that the module modifies beyond the record sets, associations, and signing configuration it declares.
- A resolution error: a `health_check` key resolved to the wrong health check, or a record set placed in a zone other than the one declared.
- A dependency problem in the release pipeline that could publish unverified code.

Findings in your own inputs (for example a wildcard record or an `allow_overwrite = true` you declared) or in AWS services themselves are out of scope here; report the latter to AWS.

## Response

We acknowledge a report within 5 business days and keep you informed while we confirm, fix, and release. A fix ships as a patch release of every supported line with a `CHANGELOG.md` entry that credits the reporter unless they ask otherwise. Please give us a reasonable window before disclosing publicly.

## Security design

The module is secure by default: no record set is overwritten (`allow_overwrite = false`), no zone is destroyed with its records (`force_destroy = false`), private zones are private from creation and never gain DNSSEC or query logging, health checks are honoured only where Route 53 evaluates them, DNSSEC keys and query-log groups are validated for the `us-east-1` region and consumed by ARN without ever being modified, and the module adds only a `Name` tag. Every claim is enforced by a validation, a precondition, or a `check` block with a `terraform test` case behind it. The full description is in the [Security model](README.md#security-model) section of the README, and the reasoning in [docs/DESIGN.md](docs/DESIGN.md).
