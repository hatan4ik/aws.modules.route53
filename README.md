# aws.modules.route53

Versioned Terraform module for an explicitly owned Route 53 public hosted zone
or records in an existing zone. It never guesses a zone by name: callers either
create a named zone or supply the exact `zone_id`.
