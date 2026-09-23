# health-checks

Owns Route 53 health checks: endpoint probes (HTTP, HTTPS, string match, TCP), calculated checks over other checks, CloudWatch alarm checks, and Application Recovery Controller routing-control checks. It is a separate module because health checks are referenced by ID from record sets in any zone, have their own change cadence, and each type accepts a different set of attributes that is best validated in one place.

## Usage

```hcl
module "health_checks" {
  source = "git::https://github.com/hatan4ik/aws.modules.route53.git//modules/health-checks?ref=<commit-sha>" # v1.0.0

  health_checks = {
    primary = { type = "HTTPS", fqdn = "app.example.com", resource_path = "/health", failure_threshold = 2 }
    replica = { type = "TCP", ip_address = "192.0.2.20", port = 5432 }
    either  = { type = "CALCULATED", child_healthchecks = ["0123abcd-4567-89ef-0123-456789abcdef"], child_health_threshold = 1 }
    alarm   = { type = "CLOUDWATCH_METRIC", cloudwatch_alarm_name = "orders-5xx", cloudwatch_alarm_region = "us-east-1", insufficient_data_health_status = "LastKnownStatus" }
  }

  tags = { Environment = "prod" }
}
```

## Behaviour

- One resource per key. Every map entry is `aws_route53_health_check.this[<key>]`, tagged `Name = <key>`. IDs and ARNs are exposed by key so record sets can reference them.
- Endpoint checks (`HTTP`, `HTTPS`, `HTTP_STR_MATCH`, `HTTPS_STR_MATCH`, `TCP`) need `fqdn` or `ip_address` (both is allowed: the IP is probed and the FQDN sent as the Host header). `port` defaults to the protocol's port for HTTP and HTTPS and is required for TCP. `resource_path` must start with `/`. `request_interval` is 10 or 30 seconds (default 30) and `failure_threshold` 1 to 10 (default 3). `measure_latency` defaults to `false`. `regions` selects at least three of the eight Route 53 checker regions; unset means all of them.
- String-match checks require `search_string` (1-255 characters); other types reject it. `enable_sni` applies to HTTPS types only.
- `CALCULATED` checks need 1-256 `child_healthchecks` and a `child_health_threshold` between 0 and the number of children. `CLOUDWATCH_METRIC` checks need `cloudwatch_alarm_name` and `cloudwatch_alarm_region`, with `insufficient_data_health_status` one of `Healthy`, `Unhealthy`, or `LastKnownStatus`. `RECOVERY_CONTROL` checks need `routing_control_arn`. Each of these rejects every endpoint attribute, and endpoint checks reject theirs.
- `invert_healthcheck` and `disabled` default to `false` and apply to every type.
- Tags. `tags` apply to every check, the module adds `Name = <key>`, and each check's own `tags` are merged last so a per-check `Name` wins.

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

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_route53_health_check.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_health_check) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_health_checks"></a> [health\_checks](#input\_health\_checks) | Health checks keyed by a stable identifier. type selects the shape: HTTP, HTTPS, HTTP\_STR\_MATCH, HTTPS\_STR\_MATCH, and TCP probe an endpoint (fqdn or ip\_address); CALCULATED aggregates child\_healthchecks; CLOUDWATCH\_METRIC follows an alarm; RECOVERY\_CONTROL follows a routing control. Attributes that do not apply to the type are rejected. | <pre>map(object({<br/>    type                            = string<br/>    fqdn                            = optional(string)<br/>    ip_address                      = optional(string)<br/>    port                            = optional(number)<br/>    resource_path                   = optional(string)<br/>    search_string                   = optional(string)<br/>    request_interval                = optional(number, 30)<br/>    failure_threshold               = optional(number, 3)<br/>    measure_latency                 = optional(bool, false)<br/>    invert_healthcheck              = optional(bool, false)<br/>    disabled                        = optional(bool, false)<br/>    enable_sni                      = optional(bool)<br/>    regions                         = optional(set(string))<br/>    child_healthchecks              = optional(set(string))<br/>    child_health_threshold          = optional(number)<br/>    cloudwatch_alarm_name           = optional(string)<br/>    cloudwatch_alarm_region         = optional(string)<br/>    insufficient_data_health_status = optional(string)<br/>    routing_control_arn             = optional(string)<br/>    tags                            = optional(map(string), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every health check. Per-check tags are merged on top and the module adds Name = <key>. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_arns"></a> [arns](#output\_arns) | Health check ARNs keyed by health check key. |
| <a name="output_ids"></a> [ids](#output\_ids) | Health check IDs keyed by health check key. Reference them from record sets. |
<!-- END_TF_DOCS -->
