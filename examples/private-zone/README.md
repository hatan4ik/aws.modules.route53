# Private hosted zone

Creates a private hosted zone attached to one VPC at creation and associated
with additional VPCs in the same account through standalone associations.
Resolvers in every associated VPC answer `db.<zone>` with the address you pass
in; nothing is visible from the internet, and DNSSEC and query logging do not
apply.

The first VPC goes into the zone's own `vpc` block because Route 53 requires a
VPC to create a private zone, and it is fixed for the life of the zone. Every
further VPC becomes an `aws_route53_zone_association` keyed by its ID, so one
can be added or removed without touching the others. Cross-account associations
(an authorisation in the zone's account followed by an association from the
VPC's account) are outside the module; the module accepts only VPCs the
provider can see.

## Run

```sh
terraform init
terraform plan \
  -var zone_name=corp.internal \
  -var vpc_id=vpc-0123456789abcdef0 \
  -var 'additional_vpc_ids=["vpc-0123456789abcdef1"]' \
  -var database_ipv4_address=10.0.10.25
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
| <a name="input_additional_vpc_ids"></a> [additional\_vpc\_ids](#input\_additional\_vpc\_ids) | Further VPCs in the same account and region that resolve the zone, each as a standalone association. | `set(string)` | n/a | yes |
| <a name="input_database_ipv4_address"></a> [database\_ipv4\_address](#input\_database\_ipv4\_address) | Private IPv4 address the db record answers with. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS region of the VPCs. Route 53 is global, but a VPC association needs the VPC's region and the module defaults it to the provider's. | `string` | `"us-east-1"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the hosted zone. | `map(string)` | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC the zone is created in. It is fixed for the life of the zone. | `string` | n/a | yes |
| <a name="input_zone_name"></a> [zone\_name](#input\_zone\_name) | Name of the private hosted zone to create, for example corp.internal. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_private"></a> [private](#output\_private) | Confirms the zone was created as private. |
| <a name="output_record_fqdns"></a> [record\_fqdns](#output\_record\_fqdns) | Fully qualified names of the managed records, keyed by record key. |
| <a name="output_zone_id"></a> [zone\_id](#output\_zone\_id) | ID of the created private hosted zone. |
<!-- END_TF_DOCS -->
