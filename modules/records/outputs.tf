output "ids" {
  description = "Record set IDs (<zone id>_<fqdn>_<type>[_<set identifier>]) keyed by record key."
  value       = { for key, record in aws_route53_record.this : key => record.id }
}

output "names" {
  description = "Record names as declared (empty string for the apex) keyed by record key."
  value       = { for key, record in aws_route53_record.this : key => record.name }
}

output "fqdns" {
  description = "Fully qualified record names keyed by record key."
  value       = { for key, record in aws_route53_record.this : key => record.fqdn }
}
