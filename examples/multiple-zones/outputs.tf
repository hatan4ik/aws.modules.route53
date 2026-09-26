output "zone_ids" {
  description = "IDs of the created hosted zones, keyed by zone key."
  value       = { for key, zone in module.zone : key => zone.zone_id }
}

output "name_servers" {
  description = "Name servers of every created zone, keyed by zone key; publish the public ones at the registrar or in the parent zone."
  value       = { for key, zone in module.zone : key => zone.name_servers }
}
