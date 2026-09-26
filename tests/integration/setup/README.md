# Integration fixtures

Disposable prerequisites for the integration suites in the parent directory: a
random label that names the hosted zone under test
(`<label>.integration.invalid`) and, for the private-zone suite, two VPCs with
DNS support and hostnames enabled. `terraform test` creates them in the
caller's own account before the module under test and destroys them
afterwards. They are not a deployable pattern and are excluded from policy
scans (see `.checkov.yml` and `trivy.yaml` at the repository root).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0, < 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.35.0, < 7.0.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.6.0, < 4.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.35.0, < 7.0.0 |
| <a name="provider_random"></a> [random](#provider\_random) | >= 3.6.0, < 4.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_vpc.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [random_id.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cidr_block"></a> [cidr\_block](#input\_cidr\_block) | Address space the disposable VPCs are carved from. | `string` | `"10.99.0.0/16"` | no |
| <a name="input_create_vpcs"></a> [create\_vpcs](#input\_create\_vpcs) | Also create two VPCs with DNS support and hostnames enabled, for the private-zone suite. | `bool` | `false` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix for every disposable fixture; a random suffix is appended so concurrent runs never collide. | `string` | `"route53-it"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every fixture in addition to the identifying defaults. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_additional_vpc_id"></a> [additional\_vpc\_id](#output\_additional\_vpc\_id) | ID of the VPC associated with the zone after creation, or null when create\_vpcs is false. |
| <a name="output_name"></a> [name](#output\_name) | Unique fixture label. |
| <a name="output_region"></a> [region](#output\_region) | Region the fixtures were created in, resolved from the caller's credentials. |
| <a name="output_tags"></a> [tags](#output\_tags) | Identifying tags shared with the zone under test. |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | ID of the VPC a private zone is created in, or null when create\_vpcs is false. |
| <a name="output_zone_name"></a> [zone\_name](#output\_zone\_name) | Name of the hosted zone under test: <label>.integration.invalid. |
<!-- END_TF_DOCS -->
