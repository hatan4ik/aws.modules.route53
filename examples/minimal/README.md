# Records in an existing zone

The smallest working call of `aws.modules.route53`: two record sets in a hosted
zone that already exists. The module creates nothing but the records; the zone,
its delegation, and its NS and SOA sets stay with whoever owns the zone. Start
here when a team owns records but not the zone.

`www` is an A record answering with the addresses you pass in. `spf` is an apex
TXT that declares the domain sends no mail; TXT values carry their own double
quotes, exactly as Route 53 stores them. Neither record overwrites anything:
`allow_overwrite` defaults to `false`, so a record set created elsewhere makes
the apply fail instead of being replaced silently.

## Run

```sh
terraform init
terraform plan \
  -var zone_id=Z0123456789ABCDEFGHIJ \
  -var 'www_ipv4_addresses=["192.0.2.10","192.0.2.11"]'
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
| <a name="input_region"></a> [region](#input\_region) | AWS region the provider talks to. Route 53 is global; the region only selects the API endpoint. | `string` | `"us-east-1"` | no |
| <a name="input_www_ipv4_addresses"></a> [www\_ipv4\_addresses](#input\_www\_ipv4\_addresses) | IPv4 addresses the www record answers with. | `list(string)` | n/a | yes |
| <a name="input_zone_id"></a> [zone\_id](#input\_zone\_id) | ID of the existing hosted zone that receives the records. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_record_fqdns"></a> [record\_fqdns](#output\_record\_fqdns) | Fully qualified names of the managed records, keyed by record key. |
| <a name="output_zone_id"></a> [zone\_id](#output\_zone\_id) | ID of the hosted zone the records were created in. |
<!-- END_TF_DOCS -->
