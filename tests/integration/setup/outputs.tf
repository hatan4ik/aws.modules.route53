output "name" {
  description = "Unique fixture label."
  value       = local.name
}

output "zone_name" {
  description = "Name of the hosted zone under test: <label>.integration.invalid."
  value       = local.zone_name
}

output "vpc_id" {
  description = "ID of the VPC a private zone is created in, or null when create_vpcs is false."
  value       = var.create_vpcs ? aws_vpc.this[0].id : null
}

output "additional_vpc_id" {
  description = "ID of the VPC associated with the zone after creation, or null when create_vpcs is false."
  value       = var.create_vpcs ? aws_vpc.this[1].id : null
}

output "region" {
  description = "Region the fixtures were created in, resolved from the caller's credentials."
  value       = data.aws_region.current.region
}

output "tags" {
  description = "Identifying tags shared with the zone under test."
  value       = local.tags
}
