# Public hosted zone

Creates a public hosted zone and its first records: the apex and `www`
answering with the addresses you pass in, and a CAA record that restricts
certificate issuance to Amazon's certificate authority. After `apply`, delegate
the domain by publishing the four `name_servers` at your registrar or as an NS
set in the parent zone; nothing resolves publicly until you do.

The zone is created without DNSSEC, so the module's advisory
`zone_created_without_dnssec` check warns on every plan. It never blocks; see
[`examples/dnssec-and-query-logging`](../dnssec-and-query-logging) to sign the
zone. `force_destroy` keeps its default of `false`, so a zone that still holds
records cannot be destroyed by accident.

## Run

```sh
terraform init
terraform plan \
  -var zone_name=example.com \
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
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the hosted zone. | `map(string)` | `{}` | no |
| <a name="input_www_ipv4_addresses"></a> [www\_ipv4\_addresses](#input\_www\_ipv4\_addresses) | IPv4 addresses the apex and www records answer with. | `list(string)` | n/a | yes |
| <a name="input_zone_name"></a> [zone\_name](#input\_zone\_name) | Name of the public hosted zone to create, for example example.com. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_name_servers"></a> [name\_servers](#output\_name\_servers) | Name servers to publish at the registrar or in the parent zone. |
| <a name="output_record_fqdns"></a> [record\_fqdns](#output\_record\_fqdns) | Fully qualified names of the managed records, keyed by record key. |
| <a name="output_zone_id"></a> [zone\_id](#output\_zone\_id) | ID of the created hosted zone. |
<!-- END_TF_DOCS -->
