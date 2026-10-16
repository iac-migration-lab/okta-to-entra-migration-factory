# Okta network zone iac-zone-office (okta-inventory/network-zones.tf), translated.
# Same range as legacy iac-legacy-nl-office: two named locations for one network, as a brownfield tenant would have.
resource "azuread_named_location" "okta_office" {
  display_name = "iac-nl-okta-office"

  ip {
    ip_ranges = ["203.0.113.0/24"] # documentation range (RFC 5737)
    trusted   = true
  }
}
