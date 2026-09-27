provider "aws" {
  region = var.region
}

# Four routing policies against two endpoints, with the health checks created
# in the same call and referenced by key. Every policy needs a set_identifier,
# and a health check is honoured only together with a policy; both rules are
# validated at plan time.
module "zone" {
  source = "../../"

  zone_id = var.zone_id

  health_checks = {
    us_east_1 = { type = "HTTPS", ip_address = var.us_east_1_ipv4_address, resource_path = "/health", failure_threshold = 2 }
    eu_west_1 = { type = "HTTPS", ip_address = var.eu_west_1_ipv4_address, resource_path = "/health", failure_threshold = 2 }
  }

  records = {
    # Weighted: shift a share of traffic to a new deployment.
    canary_stable = { name = "canary", type = "A", records = [var.us_east_1_ipv4_address], set_identifier = "stable", weighted = { weight = 90 }, health_check = "us_east_1" }
    canary_new    = { name = "canary", type = "A", records = [var.eu_west_1_ipv4_address], set_identifier = "new", weighted = { weight = 10 }, health_check = "eu_west_1" }

    # Failover: the primary answers while its health check passes.
    app_primary   = { name = "app", type = "A", records = [var.us_east_1_ipv4_address], set_identifier = "primary", failover = { type = "PRIMARY" }, health_check = "us_east_1" }
    app_secondary = { name = "app", type = "A", records = [var.eu_west_1_ipv4_address], set_identifier = "secondary", failover = { type = "SECONDARY" } }

    # Latency: resolvers get the endpoint in the closer region.
    api_us = { name = "api", type = "A", records = [var.us_east_1_ipv4_address], set_identifier = "us-east-1", latency = { region = "us-east-1" }, health_check = "us_east_1" }
    api_eu = { name = "api", type = "A", records = [var.eu_west_1_ipv4_address], set_identifier = "eu-west-1", latency = { region = "eu-west-1" }, health_check = "eu_west_1" }

    # Geolocation: European resolvers get the EU endpoint, everyone else the default.
    shop_eu      = { name = "shop", type = "A", records = [var.eu_west_1_ipv4_address], set_identifier = "europe", geolocation = { continent = "EU" } }
    shop_default = { name = "shop", type = "A", records = [var.us_east_1_ipv4_address], set_identifier = "default", geolocation = { country = "*" } }
  }

  tags = var.tags
}
