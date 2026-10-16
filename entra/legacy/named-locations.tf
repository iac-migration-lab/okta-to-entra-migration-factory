resource "azuread_named_location" "office" {
  display_name = "iac-legacy-nl-office"

  ip {
    ip_ranges = ["203.0.113.0/24"]
    trusted   = true
  }

  lifecycle {
    prevent_destroy = true
  }
}
