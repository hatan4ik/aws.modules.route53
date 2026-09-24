locals {
  zone_id = var.zone == null ? var.zone_id : aws_route53_zone.this[0].zone_id

  # An existing zone cannot be inspected without a data source, so only a zone
  # the module creates as private is known to be private.
  zone_is_private = var.zone == null ? false : var.zone.private != null

  additional_vpcs = var.zone == null ? {} : (var.zone.private == null ? {} : var.zone.private.additional_vpcs)

  # Records as handed to modules/records: health_check keys resolved to the
  # IDs of the managed health checks. An unknown key resolves to null here and
  # is rejected by the precondition on output health_check_ids.
  records = {
    for key, record in var.records : key => {
      name              = record.name
      type              = record.type
      ttl               = record.ttl
      records           = record.records
      alias             = record.alias
      set_identifier    = record.set_identifier
      health_check_id   = record.health_check == null ? record.health_check_id : lookup(module.health_checks.ids, record.health_check, null)
      weighted          = record.weighted
      latency           = record.latency
      failover          = record.failover
      geolocation       = record.geolocation
      geoproximity      = record.geoproximity
      cidr              = record.cidr
      multivalue_answer = record.multivalue_answer
      allow_overwrite   = record.allow_overwrite
    }
  }
}
