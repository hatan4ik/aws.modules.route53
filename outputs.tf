output "zone_id" {
  description = "Effective hosted-zone ID."
  value       = local.effective_zone_id
}

output "name_servers" {
  description = "Name servers when the module creates the hosted zone."
  value       = var.create_zone ? aws_route53_zone.this[0].name_servers : []
}

output "record_fqdns" {
  description = "FQDNs of managed records keyed by logical name."
  value       = { for key, record in aws_route53_record.this : key => record.fqdn }
}
