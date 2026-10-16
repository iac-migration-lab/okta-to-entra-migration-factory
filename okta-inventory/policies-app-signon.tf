resource "okta_app_signon_policy" "iac_authn_saml_apps" {
  name        = "iac-authn-saml-apps"
  description = "Lab SAML apps"
  priority    = 1
  catch_all   = true
}

resource "okta_app_signon_policy_rule" "finance_2fa" {
  policy_id                   = okta_app_signon_policy.iac_authn_saml_apps.id
  name                        = "finance-2fa"
  status                      = "ACTIVE"
  priority                    = 1
  access                      = "ALLOW"
  type                        = "ASSURANCE"
  factor_mode                 = "2FA"
  constraints                 = []
  re_authentication_frequency = "PT2H"
  groups_included             = [okta_group.finance.id]
  groups_excluded             = []
  users_included              = []
  users_excluded              = []
  user_types_included         = []
  user_types_excluded         = []
  network_connection          = "ANYWHERE"
  risk_score                  = "ANY"
  office365_client_include    = []

  keep_me_signed_in {
    post_auth = "NOT_ALLOWED"
  }
}

resource "okta_app_signon_policy_rule" "office_zone" {
  policy_id                   = okta_app_signon_policy.iac_authn_saml_apps.id
  name                        = "office-zone"
  status                      = "ACTIVE"
  priority                    = 2
  access                      = "ALLOW"
  type                        = "ASSURANCE"
  factor_mode                 = "1FA"
  constraints                 = [jsonencode({ knowledge = { types = ["password"], required = true } })]
  re_authentication_frequency = "PT2H"
  network_connection          = "ZONE"
  network_includes            = [okta_network_zone.iac_zone_office.id]
  users_included              = []
  users_excluded              = []
  user_types_included         = []
  user_types_excluded         = []
  risk_score                  = "ANY"
  office365_client_include    = []

  keep_me_signed_in {
    post_auth = "NOT_ALLOWED"
  }
}

# System rule: Okta rejects changes to its conditions (E0000077). Inventory only; never applied.
resource "okta_app_signon_policy_rule" "catch_all_rule" {
  policy_id                   = okta_app_signon_policy.iac_authn_saml_apps.id
  name                        = "Catch-all Rule"
  status                      = "ACTIVE"
  priority                    = 99
  access                      = "ALLOW"
  type                        = "ASSURANCE"
  factor_mode                 = "1FA"
  constraints                 = [jsonencode({ knowledge = { types = ["password"], required = true } })]
  re_authentication_frequency = "PT2H"
  keep_me_signed_in {
    post_auth = "NOT_ALLOWED"
  }

  # API returns conditions null for system rules; the provider defaults network_connection to ANYWHERE,
  # so plan shows a diff whether the argument is null or ANYWHERE (run 1 finding).
  lifecycle {
    ignore_changes = [network_connection]
  }
}
