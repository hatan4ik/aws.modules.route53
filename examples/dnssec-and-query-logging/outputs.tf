output "zone_id" {
  description = "ID of the created hosted zone."
  value       = module.zone.zone_id
}

output "name_servers" {
  description = "Name servers to publish at the registrar or in the parent zone."
  value       = module.zone.name_servers
}

output "ds_record" {
  description = "DS record to publish in the parent zone to complete the DNSSEC chain of trust."
  value       = module.zone.dnssec_key_signing_key.ds_record
}

output "query_log_id" {
  description = "ID of the query logging configuration."
  value       = module.zone.query_log_id
}
