output "zone_id" {
  description = "ID of the hosted zone, created or supplied."
  value       = local.zone_id

  precondition {
    condition     = (var.zone_id == null) != (var.zone == null)
    error_message = "Set exactly one of zone_id (an existing hosted zone) or zone (a hosted zone to create)."
  }
}

output "zone_arn" {
  description = "ARN of the created hosted zone, or null for an existing zone."
  value       = var.zone == null ? null : aws_route53_zone.this[0].arn
}

output "name" {
  description = "Name of the created hosted zone, or null for an existing zone."
  value       = var.zone == null ? null : aws_route53_zone.this[0].name
}

output "name_servers" {
  description = "Name servers of the created hosted zone to delegate to from the parent zone; empty for an existing zone."
  value       = var.zone == null ? [] : aws_route53_zone.this[0].name_servers
}

output "primary_name_server" {
  description = "Primary name server of the created hosted zone (the SOA MNAME), or null for an existing zone."
  value       = var.zone == null ? null : aws_route53_zone.this[0].primary_name_server
}

output "private" {
  description = "Whether the created hosted zone is private, or null for an existing zone (the module does not look it up)."
  value       = var.zone == null ? null : var.zone.private != null
}

output "record_fqdns" {
  description = "Fully qualified record names keyed by record key."
  value       = module.records.fqdns
}

output "record_names" {
  description = "Record names as declared (empty string for the apex) keyed by record key."
  value       = module.records.names
}

output "health_check_ids" {
  description = "Health check IDs keyed by health check key."
  value       = module.health_checks.ids

  precondition {
    condition     = alltrue([for record in values(var.records) : record.health_check == null ? true : contains(keys(var.health_checks), record.health_check)])
    error_message = "Every records[*].health_check must name a key of health_checks."
  }
}

output "health_check_arns" {
  description = "Health check ARNs keyed by health check key."
  value       = module.health_checks.arns
}

output "dnssec_key_signing_key" {
  description = "Key-signing key details when dnssec is set, or null: ds_record to publish in the parent zone, dnskey_record, key_tag, and public_key."
  value = var.dnssec == null ? null : {
    ds_record     = aws_route53_key_signing_key.this[0].ds_record
    dnskey_record = aws_route53_key_signing_key.this[0].dnskey_record
    key_tag       = aws_route53_key_signing_key.this[0].key_tag
    public_key    = aws_route53_key_signing_key.this[0].public_key
  }
}

output "query_log_id" {
  description = "ID of the query logging configuration when query_logging is set, or null."
  value       = var.query_logging == null ? null : aws_route53_query_log.this[0].id
}
