# DNSSEC signing and query logging

Creates a public hosted zone, enables DNSSEC signing with a key-signing key
backed by your KMS key, and sends every DNS query to your CloudWatch log group.
The module consumes both by ARN and validates at plan time that each lives in
`us-east-1`, the only region Route 53 accepts for them; it never creates or
modifies the key or the log group, because both outlive any single zone and
have their own owners.

After `apply`, publish `name_servers` to delegate the zone and `ds_record` in
the parent zone to complete the chain of trust. Until the DS record is
published the zone is signed but not validated by resolvers. Before destroying
the zone, remove `dnssec` and apply once so signing is disabled and the
key-signing key deactivated first; Route 53 refuses to delete a zone that is
still signed.

## Prerequisites

The key, in `us-east-1`, with the policy Route 53 documents for DNSSEC:

```hcl
resource "aws_kms_key" "dnssec" {
  provider                 = aws.us_east_1
  description              = "Route 53 DNSSEC key-signing key"
  customer_master_key_spec = "ECC_NIST_P256"
  key_usage                = "SIGN_VERIFY"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AccountAdministration"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::123456789012:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "Route53DnssecService"
        Effect    = "Allow"
        Principal = { Service = "dnssec-route53.amazonaws.com" }
        Action    = ["kms:DescribeKey", "kms:GetPublicKey", "kms:Sign"]
        Resource  = "*"
        Condition = {
          StringEquals = { "aws:SourceAccount" = "123456789012" }
          ArnLike      = { "aws:SourceArn" = "arn:aws:route53:::hostedzone/*" }
        }
      },
      {
        Sid       = "Route53DnssecServiceCreateGrant"
        Effect    = "Allow"
        Principal = { Service = "dnssec-route53.amazonaws.com" }
        Action    = "kms:CreateGrant"
        Resource  = "*"
        Condition = { Bool = { "kms:GrantIsForAWSResource" = "true" } }
      }
    ]
  })
}
```

The log group, also in `us-east-1`, and the resource policy that lets Route 53
write to every group under `/aws/route53/`:

```hcl
resource "aws_cloudwatch_log_group" "queries" {
  provider          = aws.us_east_1
  name              = "/aws/route53/example.com"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_resource_policy" "route53" {
  provider        = aws.us_east_1
  policy_name     = "route53-query-logging"
  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "Route53QueryLogging"
      Effect    = "Allow"
      Principal = { Service = "route53.amazonaws.com" }
      Action    = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource  = "arn:aws:logs:us-east-1:123456789012:log-group:/aws/route53/*"
    }]
  })
}
```

## Run

```sh
terraform init
terraform plan \
  -var zone_name=example.com \
  -var dnssec_kms_key_arn=arn:aws:kms:us-east-1:123456789012:key/0123abcd-4567-89ef-0123-456789abcdef \
  -var query_log_group_arn=arn:aws:logs:us-east-1:123456789012:log-group:/aws/route53/example.com \
  -var 'www_ipv4_addresses=["192.0.2.10"]'
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
| <a name="input_dnssec_kms_key_arn"></a> [dnssec\_kms\_key\_arn](#input\_dnssec\_kms\_key\_arn) | ARN of an asymmetric ECC\_NIST\_P256 SIGN\_VERIFY customer managed key in us-east-1 whose key policy grants dnssec-route53.amazonaws.com kms:DescribeKey, kms:GetPublicKey, kms:Sign, and kms:CreateGrant. | `string` | n/a | yes |
| <a name="input_query_log_group_arn"></a> [query\_log\_group\_arn](#input\_query\_log\_group\_arn) | ARN of an existing CloudWatch log group in us-east-1 whose resource policy lets route53.amazonaws.com call logs:CreateLogStream and logs:PutLogEvents. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS region the provider talks to. Route 53 is global; the region only selects the API endpoint. The KMS key and the log group must live in us-east-1 regardless. | `string` | `"us-east-1"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the hosted zone. | `map(string)` | `{}` | no |
| <a name="input_www_ipv4_addresses"></a> [www\_ipv4\_addresses](#input\_www\_ipv4\_addresses) | IPv4 addresses the www record answers with. | `list(string)` | n/a | yes |
| <a name="input_zone_name"></a> [zone\_name](#input\_zone\_name) | Name of the public hosted zone to create, for example example.com. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ds_record"></a> [ds\_record](#output\_ds\_record) | DS record to publish in the parent zone to complete the DNSSEC chain of trust. |
| <a name="output_name_servers"></a> [name\_servers](#output\_name\_servers) | Name servers to publish at the registrar or in the parent zone. |
| <a name="output_query_log_id"></a> [query\_log\_id](#output\_query\_log\_id) | ID of the query logging configuration. |
| <a name="output_zone_id"></a> [zone\_id](#output\_zone\_id) | ID of the created hosted zone. |
<!-- END_TF_DOCS -->
