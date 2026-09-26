provider "aws" {
  region = var.region
}

# One module call is one hosted zone. A fleet is a for_each over the module
# block, so each zone keeps its own plan, its own validation errors, and its
# own lifecycle. A zone with a vpc_id is created private in that VPC.
module "zone" {
  source   = "../../"
  for_each = var.zones

  zone = {
    name    = each.value.name
    comment = each.value.comment
    private = each.value.vpc_id == null ? null : { vpc_id = each.value.vpc_id }
  }

  tags = merge(var.tags, { Zone = each.key })
}
