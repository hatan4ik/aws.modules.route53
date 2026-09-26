mock_provider "aws" {}

variables {
  zone_id = "Z0123456789ABCDEFGHIJ"
}

run "creates_simple_and_alias_records" {
  command = plan

  variables {
    records = {
      www  = { name = "www", type = "A", records = ["192.0.2.10", "192.0.2.11"] }
      txt  = { name = "_verify", type = "TXT", ttl = 60, records = ["\"token=abc\""] }
      mail = { name = "mail", type = "CNAME", records = ["ghs.example.net."] }
      apex = { name = "@", type = "A", alias = { name = "d111111abcdef8.cloudfront.net", zone_id = "Z2FDTNDATAQYW2" } }
      root = { name = "", type = "AAAA", alias = { name = "d111111abcdef8.cloudfront.net", zone_id = "Z2FDTNDATAQYW2", evaluate_target_health = true } }
    }
  }

  assert {
    condition     = aws_route53_record.this["www"].zone_id == "Z0123456789ABCDEFGHIJ" && aws_route53_record.this["www"].name == "www" && aws_route53_record.this["www"].type == "A"
    error_message = "Records must be created in the declared zone with the declared name and type."
  }

  assert {
    condition     = aws_route53_record.this["www"].ttl == 300 && aws_route53_record.this["www"].records == toset(["192.0.2.10", "192.0.2.11"])
    error_message = "A record without a ttl must use default_ttl (300) and keep its values."
  }

  assert {
    condition     = aws_route53_record.this["txt"].ttl == 60 && aws_route53_record.this["txt"].records == toset(["\"token=abc\""])
    error_message = "An explicit ttl must pass through and TXT values must be kept verbatim."
  }

  assert {
    condition     = aws_route53_record.this["apex"].name == "" && aws_route53_record.this["root"].name == ""
    error_message = "Both @ and the empty string must address the zone apex."
  }

  assert {
    condition     = aws_route53_record.this["apex"].ttl == null && aws_route53_record.this["apex"].records == null && length(aws_route53_record.this["apex"].alias) == 1
    error_message = "Alias records must carry no ttl and no values."
  }

  assert {
    condition     = aws_route53_record.this["apex"].alias[0].name == "d111111abcdef8.cloudfront.net" && aws_route53_record.this["apex"].alias[0].zone_id == "Z2FDTNDATAQYW2" && aws_route53_record.this["apex"].alias[0].evaluate_target_health == false
    error_message = "Alias targets must pass through with evaluate_target_health defaulting to false."
  }

  assert {
    condition     = aws_route53_record.this["root"].alias[0].evaluate_target_health == true
    error_message = "evaluate_target_health must pass through when set."
  }

  assert {
    condition     = aws_route53_record.this["www"].allow_overwrite == false && aws_route53_record.this["www"].set_identifier == null && aws_route53_record.this["www"].health_check_id == null && aws_route53_record.this["www"].multivalue_answer_routing_policy == null
    error_message = "Simple records must not overwrite, and must carry no identifier, health check, or routing policy."
  }

  assert {
    condition     = length(aws_route53_record.this["www"].weighted_routing_policy) == 0 && length(aws_route53_record.this["www"].latency_routing_policy) == 0 && length(aws_route53_record.this["www"].failover_routing_policy) == 0 && length(aws_route53_record.this["www"].geolocation_routing_policy) == 0 && length(aws_route53_record.this["www"].geoproximity_routing_policy) == 0 && length(aws_route53_record.this["www"].cidr_routing_policy) == 0
    error_message = "No routing policy block may render on a simple record."
  }

  assert {
    condition     = length(output.names) == 5 && output.names["www"] == "www" && output.names["apex"] == "" && length(output.fqdns) == 5 && length(output.ids) == 5
    error_message = "Outputs must be keyed by record key."
  }
}

run "uses_declared_default_ttl" {
  command = plan

  variables {
    default_ttl = 3600
    records = {
      www = { name = "www", type = "A", records = ["192.0.2.10"] }
    }
  }

  assert {
    condition     = aws_route53_record.this["www"].ttl == 3600
    error_message = "default_ttl must apply to records without a ttl."
  }
}

run "creates_weighted_records_with_health_checks" {
  command = plan

  variables {
    records = {
      blue  = { name = "api", type = "A", records = ["192.0.2.10"], set_identifier = "blue", weighted = { weight = 80 }, health_check_id = "0123abcd-4567-89ef-0123-456789abcdef" }
      green = { name = "api", type = "A", records = ["192.0.2.20"], set_identifier = "green", weighted = { weight = 20 } }
      off   = { name = "api", type = "A", records = ["192.0.2.30"], set_identifier = "off", weighted = { weight = 0 } }
    }
  }

  assert {
    condition     = aws_route53_record.this["blue"].weighted_routing_policy[0].weight == 80 && aws_route53_record.this["blue"].set_identifier == "blue" && aws_route53_record.this["blue"].health_check_id == "0123abcd-4567-89ef-0123-456789abcdef"
    error_message = "Weighted records must carry their weight, identifier, and health check."
  }

  assert {
    condition     = aws_route53_record.this["off"].weighted_routing_policy[0].weight == 0 && aws_route53_record.this["green"].health_check_id == null
    error_message = "A zero weight is valid and a health check is optional."
  }
}

run "creates_latency_records" {
  command = plan

  variables {
    records = {
      east = { name = "api", type = "A", set_identifier = "us-east-1", latency = { region = "us-east-1" }, alias = { name = "alb-1.us-east-1.elb.amazonaws.com", zone_id = "Z35SXDOTRQ7X7K" } }
      west = { name = "api", type = "A", set_identifier = "eu-west-1", latency = { region = "eu-west-1" }, alias = { name = "alb-2.eu-west-1.elb.amazonaws.com", zone_id = "Z32O12XQLNTSW2" } }
    }
  }

  assert {
    condition     = aws_route53_record.this["east"].latency_routing_policy[0].region == "us-east-1" && aws_route53_record.this["west"].latency_routing_policy[0].region == "eu-west-1"
    error_message = "Latency records must carry their region."
  }
}

run "creates_failover_records" {
  command = plan

  variables {
    records = {
      primary   = { name = "app", type = "A", records = ["192.0.2.10"], set_identifier = "primary", failover = { type = "PRIMARY" }, health_check_id = "0123abcd-4567-89ef-0123-456789abcdef" }
      secondary = { name = "app", type = "A", records = ["192.0.2.20"], set_identifier = "secondary", failover = { type = "SECONDARY" } }
    }
  }

  assert {
    condition     = aws_route53_record.this["primary"].failover_routing_policy[0].type == "PRIMARY" && aws_route53_record.this["secondary"].failover_routing_policy[0].type == "SECONDARY"
    error_message = "Failover records must carry their role."
  }
}

run "creates_geolocation_records" {
  command = plan

  variables {
    records = {
      europe  = { name = "shop", type = "A", records = ["192.0.2.10"], set_identifier = "europe", geolocation = { continent = "EU" } }
      germany = { name = "shop", type = "A", records = ["192.0.2.20"], set_identifier = "germany", geolocation = { country = "DE" } }
      texas   = { name = "shop", type = "A", records = ["192.0.2.30"], set_identifier = "texas", geolocation = { country = "US", subdivision = "TX" } }
      default = { name = "shop", type = "A", records = ["192.0.2.40"], set_identifier = "default", geolocation = { country = "*" } }
    }
  }

  assert {
    condition     = aws_route53_record.this["europe"].geolocation_routing_policy[0].continent == "EU" && aws_route53_record.this["europe"].geolocation_routing_policy[0].country == null
    error_message = "Continent-scoped geolocation must not set a country."
  }

  assert {
    condition     = aws_route53_record.this["texas"].geolocation_routing_policy[0].country == "US" && aws_route53_record.this["texas"].geolocation_routing_policy[0].subdivision == "TX" && aws_route53_record.this["default"].geolocation_routing_policy[0].country == "*"
    error_message = "Country, subdivision, and the * default location must pass through."
  }
}

run "creates_geoproximity_records" {
  command = plan

  variables {
    records = {
      region = { name = "edge", type = "A", records = ["192.0.2.10"], set_identifier = "region", geoproximity = { aws_region = "us-west-2", bias = 10 } }
      zone   = { name = "edge", type = "A", records = ["192.0.2.20"], set_identifier = "zone", geoproximity = { local_zone_group = "usw2-las1" } }
      site   = { name = "edge", type = "A", records = ["192.0.2.30"], set_identifier = "site", geoproximity = { coordinates = { latitude = "48.85", longitude = "2.35" }, bias = -20 } }
    }
  }

  assert {
    condition     = aws_route53_record.this["region"].geoproximity_routing_policy[0].aws_region == "us-west-2" && aws_route53_record.this["region"].geoproximity_routing_policy[0].bias == 10 && length(aws_route53_record.this["region"].geoproximity_routing_policy[0].coordinates) == 0
    error_message = "Region-based geoproximity must carry the region and bias and no coordinates."
  }

  assert {
    condition     = aws_route53_record.this["zone"].geoproximity_routing_policy[0].local_zone_group == "usw2-las1" && aws_route53_record.this["zone"].geoproximity_routing_policy[0].bias == null
    error_message = "Local-zone-group geoproximity must pass through without a bias."
  }

  assert {
    condition     = tolist(aws_route53_record.this["site"].geoproximity_routing_policy[0].coordinates)[0].latitude == "48.85" && tolist(aws_route53_record.this["site"].geoproximity_routing_policy[0].coordinates)[0].longitude == "2.35" && aws_route53_record.this["site"].geoproximity_routing_policy[0].bias == -20
    error_message = "Coordinate-based geoproximity must render one coordinates block."
  }
}

run "creates_cidr_records" {
  command = plan

  variables {
    records = {
      office = { name = "intranet", type = "A", records = ["192.0.2.10"], set_identifier = "office", cidr = { collection_id = "0123abcd-4567-89ef-0123-456789abcdef", location_name = "office" } }
      other  = { name = "intranet", type = "A", records = ["192.0.2.20"], set_identifier = "other", cidr = { collection_id = "0123abcd-4567-89ef-0123-456789abcdef", location_name = "*" } }
    }
  }

  assert {
    condition     = aws_route53_record.this["office"].cidr_routing_policy[0].collection_id == "0123abcd-4567-89ef-0123-456789abcdef" && aws_route53_record.this["office"].cidr_routing_policy[0].location_name == "office" && aws_route53_record.this["other"].cidr_routing_policy[0].location_name == "*"
    error_message = "CIDR records must carry the collection and location."
  }
}

run "creates_multivalue_answer_records" {
  command = plan

  variables {
    records = {
      one = { name = "svc", type = "A", records = ["192.0.2.10"], set_identifier = "one", multivalue_answer = true, health_check_id = "0123abcd-4567-89ef-0123-456789abcdef" }
      two = { name = "svc", type = "A", records = ["192.0.2.20"], set_identifier = "two", multivalue_answer = true }
    }
  }

  assert {
    condition     = aws_route53_record.this["one"].multivalue_answer_routing_policy == true && aws_route53_record.this["two"].multivalue_answer_routing_policy == true
    error_message = "Multivalue answer records must set the routing policy flag."
  }
}

run "allows_overwrite_of_apex_ns_when_declared" {
  command = plan

  variables {
    records = {
      ns = { name = "@", type = "NS", ttl = 172800, records = ["ns-1.awsdns-00.org.", "ns-2.awsdns-00.com."], allow_overwrite = true }
    }
  }

  assert {
    condition     = aws_route53_record.this["ns"].allow_overwrite == true && aws_route53_record.this["ns"].ttl == 172800
    error_message = "An apex NS set with allow_overwrite must pass through."
  }
}

run "requires_zone_id_when_records_exist" {
  command = plan

  variables {
    zone_id = null
    records = {
      www = { name = "www", type = "A", records = ["192.0.2.10"] }
    }
  }

  expect_failures = [aws_route53_record.this]
}

run "rejects_malformed_zone_id" {
  command = plan

  variables {
    zone_id = "example.com"
  }

  expect_failures = [var.zone_id]
}

run "rejects_default_ttl_out_of_range" {
  command = plan

  variables {
    default_ttl = -1
  }

  expect_failures = [var.default_ttl]
}

run "rejects_unknown_record_type" {
  command = plan

  variables {
    records = {
      bad = { name = "www", type = "ALIAS", records = ["192.0.2.10"] }
    }
  }

  expect_failures = [var.records]
}

run "rejects_record_with_alias_and_values" {
  command = plan

  variables {
    records = {
      bad = { name = "www", type = "A", records = ["192.0.2.10"], alias = { name = "d111111abcdef8.cloudfront.net", zone_id = "Z2FDTNDATAQYW2" } }
    }
  }

  expect_failures = [var.records]
}

run "rejects_record_without_alias_or_values" {
  command = plan

  variables {
    records = {
      bad = { name = "www", type = "A", records = [] }
    }
  }

  expect_failures = [var.records]
}

run "rejects_alias_with_ttl" {
  command = plan

  variables {
    records = {
      bad = { name = "www", type = "A", ttl = 60, alias = { name = "d111111abcdef8.cloudfront.net", zone_id = "Z2FDTNDATAQYW2" } }
    }
  }

  expect_failures = [var.records]
}

run "rejects_negative_ttl" {
  command = plan

  variables {
    records = {
      bad = { name = "www", type = "A", ttl = -5, records = ["192.0.2.10"] }
    }
  }

  expect_failures = [var.records]
}

run "rejects_two_routing_policies" {
  command = plan

  variables {
    records = {
      bad = { name = "www", type = "A", records = ["192.0.2.10"], set_identifier = "x", weighted = { weight = 1 }, latency = { region = "us-east-1" } }
    }
  }

  expect_failures = [var.records]
}

run "rejects_multivalue_with_another_policy" {
  command = plan

  variables {
    records = {
      bad = { name = "www", type = "A", records = ["192.0.2.10"], set_identifier = "x", weighted = { weight = 1 }, multivalue_answer = true }
    }
  }

  expect_failures = [var.records]
}

run "rejects_routing_policy_without_set_identifier" {
  command = plan

  variables {
    records = {
      bad = { name = "www", type = "A", records = ["192.0.2.10"], weighted = { weight = 1 } }
    }
  }

  expect_failures = [var.records]
}

run "rejects_multivalue_without_set_identifier" {
  command = plan

  variables {
    records = {
      bad = { name = "www", type = "A", records = ["192.0.2.10"], multivalue_answer = true }
    }
  }

  expect_failures = [var.records]
}

run "rejects_set_identifier_without_routing_policy" {
  command = plan

  variables {
    records = {
      bad = { name = "www", type = "A", records = ["192.0.2.10"], set_identifier = "x" }
    }
  }

  expect_failures = [var.records]
}

run "rejects_cname_at_apex" {
  command = plan

  variables {
    records = {
      bad = { name = "@", type = "CNAME", records = ["example.net."] }
    }
  }

  expect_failures = [var.records]
}

run "rejects_cname_with_several_values" {
  command = plan

  variables {
    records = {
      bad = { name = "www", type = "CNAME", records = ["a.example.net.", "b.example.net."] }
    }
  }

  expect_failures = [var.records]
}

run "rejects_apex_ns_without_allow_overwrite" {
  command = plan

  variables {
    records = {
      bad = { name = "", type = "NS", records = ["ns-1.awsdns-00.org."] }
    }
  }

  expect_failures = [var.records]
}

run "rejects_apex_soa_without_allow_overwrite" {
  command = plan

  variables {
    records = {
      bad = { name = "@", type = "SOA", records = ["ns-1.awsdns-00.org. awsdns-hostmaster.amazon.com. 1 7200 900 1209600 86400"] }
    }
  }

  expect_failures = [var.records]
}

run "rejects_multivalue_alias" {
  command = plan

  variables {
    records = {
      bad = { name = "www", type = "A", set_identifier = "x", multivalue_answer = true, alias = { name = "d111111abcdef8.cloudfront.net", zone_id = "Z2FDTNDATAQYW2" } }
    }
  }

  expect_failures = [var.records]
}

run "rejects_health_check_on_simple_record" {
  command = plan

  variables {
    records = {
      bad = { name = "www", type = "A", records = ["192.0.2.10"], health_check_id = "0123abcd-4567-89ef-0123-456789abcdef" }
    }
  }

  expect_failures = [var.records]
}

run "rejects_unknown_failover_type" {
  command = plan

  variables {
    records = {
      bad = { name = "www", type = "A", records = ["192.0.2.10"], set_identifier = "x", failover = { type = "BACKUP" } }
    }
  }

  expect_failures = [var.records]
}

run "rejects_weight_out_of_range" {
  command = plan

  variables {
    records = {
      bad = { name = "www", type = "A", records = ["192.0.2.10"], set_identifier = "x", weighted = { weight = 256 } }
    }
  }

  expect_failures = [var.records]
}

run "rejects_malformed_latency_region" {
  command = plan

  variables {
    records = {
      bad = { name = "www", type = "A", records = ["192.0.2.10"], set_identifier = "x", latency = { region = "virginia" } }
    }
  }

  expect_failures = [var.records]
}

run "rejects_geolocation_with_continent_and_country" {
  command = plan

  variables {
    records = {
      bad = { name = "www", type = "A", records = ["192.0.2.10"], set_identifier = "x", geolocation = { continent = "EU", country = "DE" } }
    }
  }

  expect_failures = [var.records]
}

run "rejects_geolocation_without_location" {
  command = plan

  variables {
    records = {
      bad = { name = "www", type = "A", records = ["192.0.2.10"], set_identifier = "x", geolocation = {} }
    }
  }

  expect_failures = [var.records]
}

run "rejects_geolocation_subdivision_without_country" {
  command = plan

  variables {
    records = {
      bad = { name = "www", type = "A", records = ["192.0.2.10"], set_identifier = "x", geolocation = { continent = "NA", subdivision = "TX" } }
    }
  }

  expect_failures = [var.records]
}

run "rejects_geoproximity_without_location" {
  command = plan

  variables {
    records = {
      bad = { name = "www", type = "A", records = ["192.0.2.10"], set_identifier = "x", geoproximity = { bias = 5 } }
    }
  }

  expect_failures = [var.records]
}

run "rejects_geoproximity_with_two_locations" {
  command = plan

  variables {
    records = {
      bad = { name = "www", type = "A", records = ["192.0.2.10"], set_identifier = "x", geoproximity = { aws_region = "us-west-2", local_zone_group = "usw2-las1" } }
    }
  }

  expect_failures = [var.records]
}

run "rejects_geoproximity_bias_out_of_range" {
  command = plan

  variables {
    records = {
      bad = { name = "www", type = "A", records = ["192.0.2.10"], set_identifier = "x", geoproximity = { aws_region = "us-west-2", bias = 100 } }
    }
  }

  expect_failures = [var.records]
}

run "rejects_empty_set_identifier" {
  command = plan

  variables {
    records = {
      bad = { name = "www", type = "A", records = ["192.0.2.10"], set_identifier = "", weighted = { weight = 1 } }
    }
  }

  expect_failures = [var.records]
}
