# Staff groups from entra/platform; break-glass objects from CLI bootstrap (register #14, #15).
data "azuread_group" "staff" {
  for_each = {
    it       = "${var.name_prefix}-it"
    custserv = "${var.name_prefix}-custserv"
    finance  = "${var.name_prefix}-finance"
  }
  display_name     = each.value
  security_enabled = true
}

locals {
  bg_ca_exclusion_group_id = "21008cb0-56d6-4fc4-9f1c-9e20dc1d5620"
  owner_user_id            = "b4a88d50-ea8b-48e2-8853-7e4bd1c1c841" # la-migration-lab@outlook.com (#EXT#)

  # Entra "non-gallery application" template: what the portal uses for "Create your own application".
  non_gallery_template_id = "8adf8e6e-67b2-4cf2-a259-e3dc5476c621"

  # The "User" role every non-gallery app gets (same ID in every app).
  saml_user_role_id = "18d14569-c3bd-439b-9a66-3a2aee01d14f"

  # Test SP (docs/okta-seed-spec.md): ACS https://sptest.iamshowcase.com/acs.
  acs_url = "https://sptest.iamshowcase.com/acs"
}
