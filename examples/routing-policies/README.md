# Routing policies with health checks

Record sets in an existing zone that use four routing policies against two
endpoints, with the health checks created in the same call and referenced by
key rather than by ID:

- `canary`: weighted 90/10 between the endpoints, each backed by a health check,
  for a gradual shift to a new deployment.
- `app`: failover; the primary answers while its health check passes, the
  secondary otherwise.
- `api`: latency; resolvers get the endpoint in the closer region.
- `shop`: geolocation; European resolvers get the EU endpoint, everyone else
  the `*` default location.

Every policy needs a `set_identifier`, a health check is honoured only together
with a policy, and `health_check` must name a key of `health_checks`; all three
rules fail at plan time, not at apply time. The health checks probe
`https://<address>/health` every 30 seconds from every Route 53 checker region
and turn unhealthy after two consecutive failures.

## Run

```sh
terraform init
terraform plan \
  -var zone_id=Z0123456789ABCDEFGHIJ \
  -var us_east_1_ipv4_address=192.0.2.10 \
  -var eu_west_1_ipv4_address=198.51.100.10
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0, < 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.35.0, < 7.0.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_zone"></a> [zone](#module\_zone) | ../../ | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_eu_west_1_ipv4_address"></a> [eu\_west\_1\_ipv4\_address](#input\_eu\_west\_1\_ipv4\_address) | Public IPv4 address of the endpoint in eu-west-1; it must answer HTTPS on /health. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS region the provider talks to. Route 53 is global; the region only selects the API endpoint. | `string` | `"us-east-1"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every health check. | `map(string)` | `{}` | no |
| <a name="input_us_east_1_ipv4_address"></a> [us\_east\_1\_ipv4\_address](#input\_us\_east\_1\_ipv4\_address) | Public IPv4 address of the endpoint in us-east-1; it must answer HTTPS on /health. | `string` | n/a | yes |
| <a name="input_zone_id"></a> [zone\_id](#input\_zone\_id) | ID of the existing hosted zone that receives the records. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_health_check_ids"></a> [health\_check\_ids](#output\_health\_check\_ids) | IDs of the created health checks, keyed by health check key. |
| <a name="output_record_fqdns"></a> [record\_fqdns](#output\_record\_fqdns) | Fully qualified names of the managed records, keyed by record key. |
<!-- END_TF_DOCS -->
