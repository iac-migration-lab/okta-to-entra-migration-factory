# OIN (Okta Integration Network) catalog app, group CustServ. Placeholder workspace; exists to observe
# preconfigured-app drift in okta_app_saml (docs/terraform-provider-analysis-okta-entra-sailpoint.md).
resource "okta_app_saml" "slack" {
  label                 = "Slack"
  preconfigured_app     = "slack"
  status                = "ACTIVE"
  authentication_policy = local.default_app_signon_policy_id
  app_settings_json     = jsonencode({ domain = "iac-lab-placeholder" })
  user_name_template    = "$${source.login}"
}

resource "okta_app_group_assignments" "slack" {
  app_id = okta_app_saml.slack.id
  group {
    id       = okta_group.custserv.id
    priority = 0
    profile  = jsonencode({})
  }
}
