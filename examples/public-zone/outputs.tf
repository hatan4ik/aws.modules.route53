output "zone_id" {
  description = "ID of the created hosted zone."
  value       = module.zone.zone_id
}

output "name_servers" {
  description = "Name servers to publish at the registrar or in the parent zone."
  value       = module.zone.name_servers
}

output "record_fqdns" {
  description = "Fully qualified names of the managed records, keyed by record key."
  value       = module.zone.record_fqdns
}
