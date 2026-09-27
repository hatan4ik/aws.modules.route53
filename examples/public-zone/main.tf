provider "aws" {
  region = var.region
}

# A public hosted zone with its first records. After apply, publish the
# name_servers output at the registrar or in the parent zone to delegate.
module "zone" {
  source = "../../"

  zone = {
    name    = var.zone_name
    comment = "Public zone for ${var.zone_name}"
  }

  records = {
    apex = { name = "@", type = "A", records = var.www_ipv4_addresses }
    www  = { name = "www", type = "A", records = var.www_ipv4_addresses }

    # Only Amazon's certificate authority may issue certificates for the zone.
    caa = { name = "@", type = "CAA", records = ["0 issue \"amazon.com\""] }
  }

  tags = var.tags
}
