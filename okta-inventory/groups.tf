resource "okta_group" "it" {
  name                      = "IT"
  description               = "IT staff"
  custom_profile_attributes = jsonencode({})
}

resource "okta_group" "custserv" {
  name                      = "CustServ"
  description               = "Customer service"
  custom_profile_attributes = jsonencode({})
}

resource "okta_group" "finance" {
  name                      = "Finance"
  description               = "Finance"
  custom_profile_attributes = jsonencode({})
}

locals {
  staff_group_ids = [okta_group.finance.id, okta_group.it.id, okta_group.custserv.id]

  # Built-in default authentication policy (not seeded, not imported). Apps not mapped to iac-authn-saml-apps use it.
  default_app_signon_policy_id = "rst188pzg3iEP5uGh698"
}
