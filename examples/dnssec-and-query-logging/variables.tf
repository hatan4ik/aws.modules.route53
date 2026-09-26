variable "region" {
  description = "AWS region the provider talks to. Route 53 is global; the region only selects the API endpoint. The KMS key and the log group must live in us-east-1 regardless."
  type        = string
  default     = "us-east-1"
}

variable "zone_name" {
  description = "Name of the public hosted zone to create, for example example.com."
  type        = string
}

variable "dnssec_kms_key_arn" {
  description = "ARN of an asymmetric ECC_NIST_P256 SIGN_VERIFY customer managed key in us-east-1 whose key policy grants dnssec-route53.amazonaws.com kms:DescribeKey, kms:GetPublicKey, kms:Sign, and kms:CreateGrant."
  type        = string
}

variable "query_log_group_arn" {
  description = "ARN of an existing CloudWatch log group in us-east-1 whose resource policy lets route53.amazonaws.com call logs:CreateLogStream and logs:PutLogEvents."
  type        = string
}

variable "www_ipv4_addresses" {
  description = "IPv4 addresses the www record answers with."
  type        = list(string)

  validation {
    condition     = length(var.www_ipv4_addresses) > 0 && alltrue([for address in var.www_ipv4_addresses : can(cidrhost("${address}/32", 0))])
    error_message = "www_ipv4_addresses must hold at least one valid IPv4 address."
  }
}

variable "tags" {
  description = "Tags applied to the hosted zone."
  type        = map(string)
  default     = {}
}
