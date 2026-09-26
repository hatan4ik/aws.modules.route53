# Contributing

Thank you for improving `aws.modules.route53`. This guide covers the toolchain, the local quality gate, the integration suites, how features are tested and where they belong, commit and pull request conventions, and how releases are cut.

## Development setup

The module targets Terraform `>= 1.7.0, < 2.0.0` and is developed against 1.7.5, the version the consuming platform pins. Install the toolchain:

| Tool | Purpose | Install |
| --- | --- | --- |
| [tfenv](https://github.com/tfutils/tfenv) | Pin the Terraform version | `tfenv install 1.7.5 && tfenv use 1.7.5` |
| [tflint](https://github.com/terraform-linters/tflint) | Lint with the Terraform and AWS rulesets configured in `.tflint.hcl` | `brew install tflint && tflint --init` |
| [terraform-docs](https://terraform-docs.io) v0.20.0 | Generate the inputs and outputs tables in every README. Pinned to the version bundled by the CI docs action; newer releases change table formatting and fail the drift check (`make docs` refuses other versions). | Download the v0.20.0 binary from the [releases page](https://github.com/terraform-docs/terraform-docs/releases/tag/v0.20.0) |
| [checkov](https://www.checkov.io) | Static security policy | `pip install checkov` |
| [trivy](https://trivy.dev) | Misconfiguration scanning | `brew install trivy` |
| [pre-commit](https://pre-commit.com) | Run the gate on every commit | `pip install pre-commit && pre-commit install` |

Clone, initialise without a backend, and run the gate once to confirm the setup:

```sh
terraform init -backend=false -input=false
make check
```

## Integration suites

`tests/integration/` holds credential-driven suites that apply the module for real and destroy everything afterwards. They are never part of `make check` or the quality pipeline. Run them against your own account before a release that touches resource behaviour:

```bash
export AWS_PROFILE=<profile> AWS_REGION=<region>
make integration-smoke          # about 2 minutes: public zone, record sets of every common type, one health check
make integration-private-zone   # about 2 minutes: private zone in one VPC, associated with a second
```

Add a suite when a feature's correctness depends on the AWS API rather than on rendering (for example DNSSEC signing, which needs a real KMS key). Keep fixtures in `tests/integration/setup`, keep every value derived from the environment or the fixtures, and never reference a real account, zone, VPC, or key.

## The local gate

`make check` is the default target and the same gate CI runs. It stops at the first failing target and must pass before you open a pull request.

| Target | What it runs |
| --- | --- |
| `make fmt` | `terraform fmt -check -recursive -diff` from the repository root. `make fmt-fix` rewrites the files instead. |
| `make validate` | `make init` (`terraform init -backend=false`) followed by `terraform validate` in the root, every submodule, every example directory, and the integration fixture module. |
| `make lint` | `tflint --init` and then `tflint` in every directory with the root `.tflint.hcl`: documented and typed variables, documented outputs, snake_case naming, no unused declarations, pinned required versions and providers. |
| `make test` | `terraform test` in the root and in each `modules/*` directory. No credentials are needed. |
| `make lock` | Refresh the committed root `.terraform.lock.hcl` with hashes for linux and macOS on amd64 and arm64 after changing the provider constraint. CI runs `terraform init` before the docs drift check, so a lock file missing the Linux hash gets rewritten and fails that check. |
| `make docs` | `terraform-docs -c .terraform-docs.yml` in every directory, regenerating the tables between the `BEGIN_TF_DOCS` and `END_TF_DOCS` markers. Run it after touching any variable or output. |
| `make docs-check` | The same in `--output-check` mode: fails when a README is out of date. This is the variant `make check` and CI run. |
| `make security` | `checkov -d . --framework terraform`, and `trivy config --severity HIGH,CRITICAL` when trivy is on the PATH. The integration fixture module is excluded by `.checkov.yml` and `trivy.yaml`; nothing else is. A skip needs an inline `checkov:skip=` comment with a reason. |
| `make check` | `fmt`, `validate`, `lint`, `test`, `docs-check`, `security`, in that order. |

## Test-first workflow

Every behaviour in this module is pinned by a test before it is implemented. Write the failing `run` block first, then the code, then run `make test`.

- Tests live in `tests/*.tftest.hcl` for the root and `modules/<name>/tests/*.tftest.hcl` for each submodule. Each file starts with `mock_provider "aws" {}` and a `variables` block holding a valid baseline; each `run` overrides only what it exercises.
- Use `command = plan`. Nothing here talks to AWS, so tests run in seconds and in CI without credentials.
- Validations are tested with `expect_failures`. Point it at the object that carries the check: `[var.records]` for a variable validation, `[aws_route53_key_signing_key.this]` for a resource precondition, `[output.zone_id]` for an output precondition, `[check.force_destroy_enabled]` for a `check` block. A run with `expect_failures` passes only if exactly those objects fail; add a positive run alongside so the happy path is covered too. `expect_failures` can name root-module objects only, so a rule that a root test must target lives in the root (the `health_check` key resolution is a precondition on output `health_check_ids` for that reason) and submodule rules are tested in the submodule's own `tests/`.
- Assertions must not depend on unknown values. With a mock provider, computed attributes such as zone IDs, health check IDs, ARNs, and record FQDNs are unknown at plan time, so assert on arguments you set (`name`, `type`, `ttl`, `tags`, routing policy blocks) and on the keys of output maps (`length()`, `contains(keys(...), ...)`), never on their values.
- `||` and `&&` do not short-circuit in Terraform 1.7. Both operands are always evaluated, so `var.x == null || var.x.field > 0` fails when `x` is null. Guard with a conditional instead: `var.x == null ? true : var.x.field > 0`. This applies to validations, preconditions, and test assertions alike.
- Keep assertion `error_message` text a statement of the guaranteed behaviour. It becomes the documentation of the contract when a test fails.

## Where to add a feature

Each submodule owns one concern and has one reason to change. The root only composes.

| Concern | Lives in |
| --- | --- |
| A record-set attribute, record type, or routing policy rule | `modules/records`: add it to the `records` object type with a validation, render it in `main.tf` (a `dynamic` block for a policy), add a test. Then mirror the attribute in the root `records` type and pass it through in `locals.tf`. |
| A health check type or attribute | `modules/health-checks`: add the attribute with its per-type validation, render it in `main.tf`, add a test. Then mirror it in the root `health_checks` type. |
| Zone arguments, VPC associations, DNSSEC, query logging | Root `main.tf` and `variables.tf`. |
| Cross-resource validation the submodule cannot see (a record naming an undeclared health check, a feature refused on a private zone) | Root preconditions in `main.tf` or `outputs.tf`, or `checks.tf` when the situation is valid but usually unintended. |

Rules that apply everywhere: no data sources (validate from the identifiers the caller passes), every variable has a description, a type, and a validation where a wrong value would otherwise fail at apply time, every output has a description, defaults are the secure choice, and anything the module does not create (keys, log groups, VPCs) is consumed by ARN or ID so callers keep ownership.

## Commits

Use [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/). The scope is the submodule or root file the change touches.

```text
feat(records): add multivalue answer routing policy
fix(health-checks): accept an IPv6 ip_address
docs: describe the DS record hand-off to the parent zone
test(records): cover geoproximity coordinates
feat!: require zone_id or zone instead of create_zone
```

Append `!` after the type or scope for a breaking change and add a `BREAKING CHANGE:` footer explaining what consumers must do. Breaking changes ship only in a major release with an entry in the upgrade guide.

## Pull request checklist

- [ ] `make check` passes locally.
- [ ] New behaviour has a test; changed validations have both a passing and an `expect_failures` run.
- [ ] Variables and outputs have descriptions; `make docs` regenerated the README tables.
- [ ] A root-level attribute mirrored from a submodule is passed through in `locals.tf` and covered by a root test.
- [ ] `CHANGELOG.md` has an entry under `## [Unreleased]` in the right category.
- [ ] Breaking changes carry `!`, a `BREAKING CHANGE:` footer, and an update to `docs/UPGRADE-<major>.md`.
- [ ] Examples still initialise and validate; a new feature worth showing has an example.
- [ ] No data sources, no hard-coded account, region, or partition, no new defaults that weaken security.

## Release process

Releases are cut by maintainers.

1. Move the `## [Unreleased]` entries in `CHANGELOG.md` under a new `## [X.Y.Z] - YYYY-MM-DD` heading, add its compare link, and merge that change to `main`.
2. Create a signed annotated tag on the commit to release. The signing key must be registered with GitHub so the tag shows as Verified:

   ```sh
   git fetch origin
   git tag -s vX.Y.Z <commit> -m "aws.modules.route53 vX.Y.Z"
   git push origin vX.Y.Z
   ```

3. Dispatch the `module-release` workflow (`.github/workflows/module-release.yml`) from the tag, never from `main`: `gh workflow run module-release.yml --ref vX.Y.Z -f release_tag=vX.Y.Z`. It verifies that the signed tag points at the revision it checked out, then formatting, validation, tests, and generated docs, and publishes the GitHub release. A maintenance release for an older line (a 0.1.x fix after 1.0.0 landed on `main`) is cut from that line's commit the same way.
4. Announce the release with the commit SHA. Consumers pin that SHA, not the tag:

   ```hcl
   source = "git::https://github.com/hatan4ik/aws.modules.route53.git?ref=<commit-sha>" # vX.Y.Z
   ```

Tags are never moved or deleted once published. A bad release is followed by a new patch release.
