resource "azuread_group" "finance_users" {
  display_name     = "iac-legacy-finance-users"
  mail_enabled     = false
  mail_nickname    = "22c49acb-8"
  security_enabled = true
  members          = []

  lifecycle {
    prevent_destroy = true
  }
}

resource "azuread_group" "privileged_admins" {
  display_name     = "iac-legacy-privileged-admins"
  mail_enabled     = false
  mail_nickname    = "08bbdd27-a"
  security_enabled = true
  members          = ["1028c48b-19bd-4852-85a4-2cd92e274b06"] # iac-lab-admin

  lifecycle {
    prevent_destroy = true
  }
}
