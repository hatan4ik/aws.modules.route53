provider "aws" {
  region = var.region
}

# Record sets in a hosted zone that already exists. The module creates nothing
# but the records; the zone, its delegation, and its NS and SOA sets stay with
# whoever owns the zone.
module "zone" {
  source = "../../"

  zone_id = var.zone_id

  records = {
    www = { name = "www", type = "A", records = var.www_ipv4_addresses }

    # An apex TXT declaring that the domain sends no mail. TXT values carry
    # their own double quotes, exactly as Route 53 stores them.
    spf = { name = "@", type = "TXT", ttl = 3600, records = ["\"v=spf1 -all\""] }
  }
}
