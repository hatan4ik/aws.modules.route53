output "zone_id" {
  description = "ID of the hosted zone the records were created in."
  value       = module.zone.zone_id
}

output "record_fqdns" {
  description = "Fully qualified names of the managed records, keyed by record key."
  value       = module.zone.record_fqdns
}
