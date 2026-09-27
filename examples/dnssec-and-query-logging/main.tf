provider "aws" {
  region = var.region
}

# A signed, logged public hosted zone. The module consumes the KMS key and the
# log group by ARN and never creates or modifies them; the README shows the
# key policy and the log resource policy Route 53 requires.
module "zone" {
  source = "../../"

  zone = {
    name = var.zone_name
  }

  # An asymmetric ECC_NIST_P256 SIGN_VERIFY key in us-east-1. The module
  # validates the ARN's region at plan time.
  dnssec = {
    kms_key_arn = var.dnssec_kms_key_arn
  }

  # A log group in us-east-1 whose resource policy lets route53.amazonaws.com
  # create streams and put events.
  query_logging = {
    cloudwatch_log_group_arn = var.query_log_group_arn
  }

  records = {
    www = { name = "www", type = "A", records = var.www_ipv4_addresses }
  }

  tags = var.tags
}
