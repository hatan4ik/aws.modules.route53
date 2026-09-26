# Multiple zones

One module call is one hosted zone. A fleet is a `for_each` over the module
block: each zone keeps its own plan, its own validation errors, and its own
lifecycle, and the map key becomes the address in state
(`module.zone["internal"].aws_route53_zone.this[0]`). The value names the zone
and, for a private zone, the VPC it is created in; everything else keeps the
module's defaults.

Records and health checks are per zone and would be declared in the same map
entry when a fleet needs them; this example keeps the entries minimal to show
the shape of the loop.

## Run

```sh
terraform init
terraform plan \
  -var 'zones={ public = { name = "example.com", comment = "Customer-facing zone" }, internal = { name = "example.internal", vpc_id = "vpc-0123456789abcdef0" } }'
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
| <a name="input_region"></a> [region](#input\_region) | AWS region the provider talks to. Route 53 is global; the region is also the region of any VPC named in zones. | `string` | `"us-east-1"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every hosted zone; the module adds Name and this example adds Zone = <key>. | `map(string)` | `{}` | no |
| <a name="input_zones"></a> [zones](#input\_zones) | Hosted zones keyed by a stable identifier. vpc\_id makes the zone private and creates it in that VPC; without it the zone is public. | <pre>map(object({<br/>    name    = string<br/>    comment = optional(string)<br/>    vpc_id  = optional(string)<br/>  }))</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_name_servers"></a> [name\_servers](#output\_name\_servers) | Name servers of every created zone, keyed by zone key; publish the public ones at the registrar or in the parent zone. |
| <a name="output_zone_ids"></a> [zone\_ids](#output\_zone\_ids) | IDs of the created hosted zones, keyed by zone key. |
<!-- END_TF_DOCS -->
