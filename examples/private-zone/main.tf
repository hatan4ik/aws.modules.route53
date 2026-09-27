provider "aws" {
  region = var.region
}

# A private hosted zone created in one VPC and associated with further VPCs in
# the same account. Route 53 needs a VPC to create a private zone, so the first
# one goes into the zone itself; every additional VPC is a standalone
# association, and the zone ignores later changes to its own vpc block so the
# two never fight over the association list.
module "zone" {
  source = "../../"

  zone = {
    name = var.zone_name
    private = {
      vpc_id          = var.vpc_id
      additional_vpcs = { for vpc_id in var.additional_vpc_ids : vpc_id => {} }
    }
  }

  records = {
    db = { name = "db", type = "A", records = [var.database_ipv4_address] }
  }

  tags = var.tags
}
