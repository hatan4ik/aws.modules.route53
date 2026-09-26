output "ids" {
  description = "Health check IDs keyed by health check key. Reference them from record sets."
  value       = { for key, check in aws_route53_health_check.this : key => check.id }
}

output "arns" {
  description = "Health check ARNs keyed by health check key."
  value       = { for key, check in aws_route53_health_check.this : key => check.arn }
}
