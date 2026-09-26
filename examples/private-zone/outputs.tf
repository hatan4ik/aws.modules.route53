output "zone_id" {
  description = "ID of the created private hosted zone."
  value       = module.zone.zone_id
}

output "private" {
  description = "Confirms the zone was created as private."
  value       = module.zone.private
}

output "record_fqdns" {
  description = "Fully qualified names of the managed records, keyed by record key."
  value       = module.zone.record_fqdns
}
