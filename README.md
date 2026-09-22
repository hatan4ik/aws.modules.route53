# aws.modules.route53

Versioned Terraform module for an explicitly owned Route 53 public hosted zone
or records in an existing zone. It never guesses a zone by name: callers either
create a named zone or supply the exact `zone_id`.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0, < 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0, < 7.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.66.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_route53_record.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_zone.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone) | resource |
| [terraform_data.input_contract](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_create_zone"></a> [create\_zone](#input\_create\_zone) | Whether to create a public hosted zone. | `bool` | `false` | no |
| <a name="input_force_destroy"></a> [force\_destroy](#input\_force\_destroy) | Whether a managed zone may be destroyed with records. Keep false in production. | `bool` | `false` | no |
| <a name="input_records"></a> [records](#input\_records) | Record sets keyed by a stable logical name. Alias and records are mutually exclusive. | <pre>map(object({<br/>    name    = string<br/>    type    = string<br/>    ttl     = optional(number)<br/>    records = optional(set(string))<br/>    alias = optional(object({<br/>      name                   = string<br/>      zone_id                = string<br/>      evaluate_target_health = optional(bool, false)<br/>    }))<br/>  }))</pre> | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied when the module creates a hosted zone. | `map(string)` | `{}` | no |
| <a name="input_zone_id"></a> [zone\_id](#input\_zone\_id) | Existing Route 53 hosted-zone ID. Required unless create\_zone is true. | `string` | `null` | no |
| <a name="input_zone_name"></a> [zone\_name](#input\_zone\_name) | Hosted-zone name, without relying on an implicit trailing dot. | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_name_servers"></a> [name\_servers](#output\_name\_servers) | Name servers when the module creates the hosted zone. |
| <a name="output_record_fqdns"></a> [record\_fqdns](#output\_record\_fqdns) | FQDNs of managed records keyed by logical name. |
| <a name="output_zone_id"></a> [zone\_id](#output\_zone\_id) | Effective hosted-zone ID. |
<!-- END_TF_DOCS -->