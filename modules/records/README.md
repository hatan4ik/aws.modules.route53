# records

Owns record sets in one hosted zone: every routing policy Route 53 supports, alias targets, health-check references, and the plan-time validation of the rules Route 53 otherwise enforces at apply time. It is a separate module because record sets have their own reviewers and change cadence, and because the same shape must work against a zone the root module created, a zone supplied by ID, or a zone owned by another configuration entirely.

## Usage

```hcl
module "records" {
  source = "git::https://github.com/hatan4ik/aws.modules.route53.git//modules/records?ref=<commit-sha>" # v1.0.0

  zone_id = "Z0123456789ABCDEFGHIJ"

  records = {
    apex = { name = "@", type = "A", alias = { name = "d111111abcdef8.cloudfront.net", zone_id = "Z2FDTNDATAQYW2" } }
    www  = { name = "www", type = "CNAME", records = ["d111111abcdef8.cloudfront.net"] }
    spf  = { name = "@", type = "TXT", ttl = 3600, records = ["\"v=spf1 include:_spf.example.net -all\""] }

    api_blue  = { name = "api", type = "A", records = ["192.0.2.10"], set_identifier = "blue", weighted = { weight = 90 }, health_check_id = "0123abcd-4567-89ef-0123-456789abcdef" }
    api_green = { name = "api", type = "A", records = ["192.0.2.20"], set_identifier = "green", weighted = { weight = 10 } }
  }
}
```

## Behaviour

- One resource per key. Every map entry is `aws_route53_record.this[<key>]`. Keys are stable identifiers: renaming a key replaces that record set only. IDs, declared names, and FQDNs are exposed by key.
- Names. `name` is relative to the zone (`www`) or fully qualified (`www.example.com.`); the provider expands relative names. `""` and `@` both mean the zone apex.
- Values or alias. Each record declares exactly one of a non-empty `records` set or an `alias` target (`name`, `zone_id`, `evaluate_target_health` defaulting to `false`). Alias records take no `ttl`; other records use `ttl` or `default_ttl` (300 seconds).
- Routing policies. At most one of `weighted` (`weight` 0-255), `latency` (`region`), `failover` (`type` PRIMARY or SECONDARY), `geolocation` (exactly one of `continent` or `country`, `subdivision` with `country`, `country = "*"` for the default location), `geoproximity` (exactly one of `aws_region`, `local_zone_group`, or `coordinates`, plus `bias` from -99 to 99), `cidr` (`collection_id`, `location_name`, `*` for the default), or `multivalue_answer = true`. Any policy requires `set_identifier` (1-128 characters), and `set_identifier` is rejected without a policy.
- Health checks. `health_check_id` is accepted only with a routing policy; Route 53 ignores it on simple records, so the module refuses it there rather than let the caller believe a check applies. Multivalue answer records cannot be aliases.
- Apex rules. A CNAME at the apex is rejected (use an alias). Route 53 creates the apex NS and SOA sets with the zone, so managing them requires `allow_overwrite = true`; the module rejects the combination otherwise. `allow_overwrite` defaults to `false` on every record so nothing created elsewhere is silently replaced.
- CNAME record sets hold exactly one value.
- TXT and SPF. Values are passed verbatim and must carry their own double quotes, for example `"\"v=spf1 -all\""`. A value longer than 255 characters must be split into quoted chunks separated by a space inside one string (`"\"chunk one\" \"chunk two\""`).
- `zone_id`. Required whenever `records` is non-empty; a precondition on the record resource names it. It is validated as a hosted zone ID, not a zone name.

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
| [aws_route53_record.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_default_ttl"></a> [default\_ttl](#input\_default\_ttl) | TTL in seconds applied to non-alias records that declare no ttl. | `number` | `300` | no |
| <a name="input_records"></a> [records](#input\_records) | Record sets keyed by a stable identifier. name is relative to the zone or a fully qualified name; empty or @ is the apex. Exactly one of records or alias; at most one routing policy, which requires set\_identifier. TXT and SPF values must carry their own double quotes ("v=spf1 -all"); values longer than 255 characters are split into quoted chunks by the caller. | <pre>map(object({<br/>    name    = string<br/>    type    = string<br/>    ttl     = optional(number)<br/>    records = optional(set(string))<br/>    alias = optional(object({<br/>      name                   = string<br/>      zone_id                = string<br/>      evaluate_target_health = optional(bool, false)<br/>    }))<br/>    set_identifier  = optional(string)<br/>    health_check_id = optional(string)<br/>    weighted = optional(object({<br/>      weight = number<br/>    }))<br/>    latency = optional(object({<br/>      region = string<br/>    }))<br/>    failover = optional(object({<br/>      type = string<br/>    }))<br/>    geolocation = optional(object({<br/>      continent   = optional(string)<br/>      country     = optional(string)<br/>      subdivision = optional(string)<br/>    }))<br/>    geoproximity = optional(object({<br/>      aws_region       = optional(string)<br/>      local_zone_group = optional(string)<br/>      bias             = optional(number)<br/>      coordinates = optional(object({<br/>        latitude  = string<br/>        longitude = string<br/>      }))<br/>    }))<br/>    cidr = optional(object({<br/>      collection_id = string<br/>      location_name = string<br/>    }))<br/>    multivalue_answer = optional(bool, false)<br/>    allow_overwrite   = optional(bool, false)<br/>  }))</pre> | `{}` | no |
| <a name="input_zone_id"></a> [zone\_id](#input\_zone\_id) | Hosted zone the record sets belong to. Required whenever records is non-empty; the resource precondition names it. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_fqdns"></a> [fqdns](#output\_fqdns) | Fully qualified record names keyed by record key. |
| <a name="output_ids"></a> [ids](#output\_ids) | Record set IDs (<zone id>\_<fqdn>\_<type>[\_<set identifier>]) keyed by record key. |
| <a name="output_names"></a> [names](#output\_names) | Record names as declared (empty string for the apex) keyed by record key. |
<!-- END_TF_DOCS -->
