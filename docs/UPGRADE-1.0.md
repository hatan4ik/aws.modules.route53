# Upgrading from 0.1.x to 1.0.0

## What changed and why

Version 0.1.x created a public hosted zone or managed simple and alias record sets in an existing one, guarded its three loosely coupled zone inputs with a `terraform_data` precondition carrier, and set `allow_overwrite = true` on every record. Version 1.0.0 manages one hosted zone per module call that is either created from a `zone` object (public, or private with VPC associations) or supplied by `zone_id`, moves record sets into `modules/records` with every routing policy and plan-time validation of Route 53's rules, adds `modules/health-checks` with health checks referenced by key, and makes DNSSEC signing and query logging opt-in declarations. The reasons, and the table of 0.1.x behaviours that were replaced, are in [DESIGN.md](DESIGN.md). This guide gets an existing 0.1.x consumer onto 1.0.0 without recreating the zone or any record set.

## Input mapping

Root inputs of 0.1.2:

| 0.1.x input | 1.0.0 equivalent |
| --- | --- |
| `create_zone = true` with `zone_name` | `zone = { name = var.zone_name }`. The zone object also takes `comment`, `delegation_set_id`, and `private`, none of which 0.1.x could express. |
| `create_zone = false` with `zone_id` | `zone_id`, unchanged. `create_zone` is removed; exactly one of `zone_id` or `zone` must be set, and the precondition on output `zone_id` names the rule. |
| `zone_name` | `zone.name`. Same validation intent (a DNS name, optionally with a trailing dot); the name is now checked at plan time. |
| `force_destroy` | `zone.force_destroy` (default `false`, unchanged). It applies only to a created zone, as before, and the `force_destroy_enabled` check now warns while it is on. |
| `records` | `records`, same map shape: `name`, `type`, `ttl`, `records`, and `alias = { name, zone_id, evaluate_target_health }` are unchanged. New optional attributes: `set_identifier`, `health_check`, `health_check_id`, `weighted`, `latency`, `failover`, `geolocation`, `geoproximity`, `cidr`, `multivalue_answer`, and `allow_overwrite`. |
| implicit 300-second TTL | `default_ttl` (default 300). A record without `ttl` gets the same value as before. |
| implicit `allow_overwrite = true` | `records.<key>.allow_overwrite` (default `false`). Set it to `true` per record to keep the 0.1.x behaviour; see "Preserving existing record sets". |
| `tags` | `tags`, same shape. Now also applied to every health check, and the module adds `Name = <zone name>` to the zone. |

New in 1.0.0 with no 0.1.x counterpart: `zone.comment`, `zone.delegation_set_id`, `zone.private`, `health_checks`, `dnssec`, and `query_logging`. All default to empty or `null`, so an upgraded configuration that does not use them behaves as before.

Outputs `zone_id`, `name_servers`, and `record_fqdns` keep their names and shapes. New outputs: `zone_arn`, `name`, `primary_name_server`, `private`, `record_names`, `health_check_ids`, `health_check_arns`, `dnssec_key_signing_key`, and `query_log_id`.

A complete rewrite for a consumer whose 0.1.x block was `module "dns"` creating a zone with two records:

```hcl
# 0.1.x
module "dns" {
  source = "git::https://github.com/hatan4ik/aws.modules.route53.git?ref=v0.1.2"

  create_zone   = true
  zone_name     = "example.com"
  force_destroy = false
  tags          = var.tags

  records = {
    www = { name = "www", type = "A", records = ["192.0.2.10"] }
    cdn = { name = "cdn", type = "A", alias = { name = "d111111abcdef8.cloudfront.net", zone_id = "Z2FDTNDATAQYW2" } }
  }
}

# 1.0.0
module "dns" {
  source = "git::https://github.com/hatan4ik/aws.modules.route53.git?ref=<commit-sha>" # v1.0.0

  zone = {
    name          = "example.com"
    force_destroy = false
  }
  tags = var.tags

  records = {
    # allow_overwrite = true keeps the 0.1.x behaviour for record sets the
    # module took over from elsewhere; drop it once you know every set is
    # managed here (see "Preserving existing record sets").
    www = { name = "www", type = "A", records = ["192.0.2.10"], allow_overwrite = true }
    cdn = { name = "cdn", type = "A", alias = { name = "d111111abcdef8.cloudfront.net", zone_id = "Z2FDTNDATAQYW2" }, allow_overwrite = true }
  }
}
```

A consumer managing records in an existing zone changes only the source: `zone_id` and `records` are accepted as they were, and `create_zone = false` is dropped.

## Preserving existing record sets

Nothing about the zone changes: `aws_route53_zone.this[0]` keeps its address, name, and `force_destroy` value, and gains a `Name` tag in place. Record sets are updated in place as long as their `name`, `type`, and values are unchanged; only their state address moves (next section).

`allow_overwrite` is the one behavioural change to think about:

- Record sets already in Terraform state are unaffected. The flag only matters when Terraform creates a record set, and those are updates.
- A record set in the zone that Terraform does not yet know about (one that 0.1.x would have taken over on the next apply) now fails the apply with `Tried to create resource record set ... but it already exists`. Either set `allow_overwrite = true` on that record to take it over deliberately, or import it.
- 0.1.x could silently replace the apex NS and SOA sets with a `records` entry. 1.0.0 rejects such an entry at plan time unless it carries `allow_overwrite = true`.

Two rendering details change without any plan diff: `ttl` and `records` are `null` on alias records in both versions, and record values that were a list are now a set. A record without `ttl` still gets 300 seconds.

## State moves

Old addresses are those of 0.1.2 under `module.dns` with record keys `www` and `cdn`. New addresses are under the same module block.

| 0.1.2 address | 1.0.0 address |
| --- | --- |
| `module.dns.aws_route53_zone.this[0]` | `module.dns.aws_route53_zone.this[0]` (unchanged) |
| `module.dns.aws_route53_record.this["www"]` | `module.dns.module.records.aws_route53_record.this["www"]` |
| `module.dns.aws_route53_record.this["cdn"]` | `module.dns.module.records.aws_route53_record.this["cdn"]` |
| `module.dns.terraform_data.input_contract` | Not moved. Destroyed; it never touched AWS. |

Ready to paste into your root configuration. Repeat the record block for every key in your `records` map.

```hcl
moved {
  from = module.dns.aws_route53_record.this["www"]
  to   = module.dns.module.records.aws_route53_record.this["www"]
}

moved {
  from = module.dns.aws_route53_record.this["cdn"]
  to   = module.dns.module.records.aws_route53_record.this["cdn"]
}
```

For a consumer that already uses `for_each` on the module block, prefix both sides with the instance key, for example `module.dns["prod"].aws_route53_record.this["www"]`.

## Procedure

1. Pin the 1.0.0 release: copy the commit SHA of tag `v1.0.0` into `?ref=<commit-sha>` and put the tag in a trailing comment.
2. Rewrite the module block as shown above: `zone = { name, force_destroy }` in place of `create_zone`, `zone_name`, and `force_destroy`, or keep `zone_id` and drop `create_zone = false`. Leave `records` and `tags` as they are.
3. Decide on `allow_overwrite` per record: `true` to keep taking over record sets that exist outside Terraform, the default `false` once every set is managed here.
4. Add the `moved` blocks for every record key.
5. Run `terraform init -upgrade` to fetch the new module source, then `terraform plan`.
6. Verify the plan. There must be no replacement or destruction of `aws_route53_zone` or `aws_route53_record`. Expect: every record set moved to its `module.records` address with no change, the zone updated in place with the `Name` tag, and `terraform_data.input_contract` destroyed. If a record set shows `must be replaced`, compare its `name` and `type` with the 0.1.x values; a trailing dot added or removed from `name` counts as a change to Route 53.
7. Apply. No DNS answer changes: record sets are updated in place or not at all.
8. Remove the `moved` blocks in a later change once every workspace that used 0.1.x has applied the upgrade.
