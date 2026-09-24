# Advisory checks: they warn on every plan and apply but never block. Each
# describes a configuration that is valid yet usually unintended.

check "force_destroy_enabled" {
  assert {
    condition     = var.zone == null ? true : !var.zone.force_destroy
    error_message = "zone.force_destroy is enabled: destroying this module deletes every record set in the zone along with it. Keep it false outside disposable environments."
  }
}

check "zone_created_without_dnssec" {
  assert {
    condition     = var.zone == null ? true : (var.zone.private != null || var.dnssec != null)
    error_message = "A public hosted zone is being created without DNSSEC signing. Declare dnssec with a us-east-1 KMS key and publish the DS record in the parent zone, or accept an unsigned zone deliberately."
  }
}
