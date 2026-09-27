output "health_check_ids" {
  description = "IDs of the created health checks, keyed by health check key."
  value       = module.zone.health_check_ids
}

output "record_fqdns" {
  description = "Fully qualified names of the managed records, keyed by record key."
  value       = module.zone.record_fqdns
}
