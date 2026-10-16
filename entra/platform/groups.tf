# Staff groups, one per Okta group (okta-inventory/groups.tf). Membership comes from provisioning
# (run 1: CLI, findings 2026-10-16), so Terraform manages the group, not its members.
locals {
  staff_groups = {
    it       = { name = "iac-it", description = "IT staff (Okta group IT)" }
    custserv = { name = "iac-custserv", description = "Customer service (Okta group CustServ)" }
    finance  = { name = "iac-finance", description = "Finance (Okta group Finance)" }
  }
}

resource "azuread_group" "staff" {
  for_each = local.staff_groups

  display_name     = each.value.name
  description      = each.value.description
  security_enabled = true

  lifecycle {
    ignore_changes = [members]
  }
}
