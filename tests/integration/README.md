# Integration suites

The suites in this directory apply the module for real in **your** AWS account
and destroy everything afterwards. They complement the contract tests in
`tests/`, which run with `mock_provider`, need no credentials, and use the AWS
documentation placeholder account `123456789012` and fake zone, VPC, and key
IDs on purpose: they prove the module's interface and rendering, not that AWS
accepts it. These suites prove the latter.

Nothing here is tied to an account, region, or landing zone. Credentials and
the region come from the environment; every prerequisite is a disposable
fixture created by [`setup/`](setup/) with a random suffix, so concurrent runs
never collide. The zone under test is named `<label>.integration.invalid`: the
`.invalid` top-level domain is reserved by RFC 2606, so the name can never
collide with a real domain and is never delegated.

| Suite | What it proves | Creates | Needs | Typical time |
| --- | --- | --- | --- | --- |
| `smoke.tftest.hcl` | A public hosted zone, record sets of every common type (A, AAAA, CNAME, TXT, MX, CAA, SRV, and a failover pair), and a health check referenced by key are accepted by the APIs and torn down with `force_destroy`. | one zone, ten record sets, one disabled health check | credentials, region | about 2 minutes |
| `private-zone.tftest.hcl` | A private hosted zone is created in one VPC and associated with a second through a standalone association. | two VPCs, one zone, one record set, one association | credentials, region | about 2 minutes |

Cost: Route 53 does not charge for a hosted zone deleted within 12 hours of
creation, and both suites finish in minutes. The health check in `smoke` is
charged pro rata for the minutes it exists; it is disabled, so it never probes
anything. VPCs without attached resources are free.

## Run it in your account

```bash
export AWS_PROFILE=<your profile>   # or AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY / AWS_SESSION_TOKEN
export AWS_REGION=<region>
make integration-smoke              # terraform init -test-directory=tests/integration && terraform test -test-directory=tests/integration -filter=tests/integration/smoke.tftest.hcl
make integration-private-zone
```

The credentials need the permissions in
[`iam/integration-permissions-policy.json`](iam/integration-permissions-policy.json):
VPC creation and deletion for the fixtures, and hosted zone, record set,
health check, and VPC association management for the module under test.
Route 53 is global, so the policy needs no region scoping; hosted zones and
health checks do not support resource-level ARNs in IAM before they exist,
which is why those statements use `"Resource": "*"`.

`terraform test` runs `tests/` only by default, so these suites never run in
the credential-free quality pipeline. The fixture module is excluded from the
Checkov and Trivy scans (`.checkov.yml`, `trivy.yaml`) because it is
short-lived test infrastructure, not a deployable pattern.

## Run it from GitHub Actions (owner lane)

The `integration` workflow (`.github/workflows/integration.yml`) is dispatch-only
and assumes a role through GitHub OIDC. It reads everything account-specific
from the protected `integration` environment of the repository, so the code
stays universal:

| Environment variable | Meaning |
| --- | --- |
| `AWS_INTEGRATION_ROLE_ARN` | Role the workflow assumes. Trust policy: [`iam/github-oidc-trust-policy.json`](iam/github-oidc-trust-policy.json) with `<OWNER>/<REPO>` set to this repository; permissions: the policy above. |
| `AWS_INTEGRATION_REGION` | Region for the disposable fixtures. |

Dispatch with `gh workflow run integration.yml -f suite=smoke` (or
`private-zone`). Protect the environment with required reviewers so a run
cannot be started from a pull request by anyone with write access.

For this repository's owner the environment is prepared with the sandbox
region; the role ARN is added once the role exists in the sandbox account,
created through the platform's delivery IAM module with the trust policy above
and the subject `repo:hatan4ik/aws.modules.route53:environment:integration`.
