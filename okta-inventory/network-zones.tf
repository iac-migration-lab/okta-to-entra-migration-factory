resource "okta_network_zone" "iac_zone_office" {
  name     = "iac-zone-office"
  type     = "IP"
  usage    = "POLICY"
  status   = "ACTIVE"
  gateways = ["203.0.113.0/24"] # documentation range (RFC 5737)
}
