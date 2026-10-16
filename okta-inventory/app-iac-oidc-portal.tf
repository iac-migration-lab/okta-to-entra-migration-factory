# OIDC web app, group IT. Authorization Code; tester https://oidcdebugger.com/debug.
# Okta holds a client secret for it (client_secret_basic); it is never read into Terraform or Git.
resource "okta_app_oauth" "iac_oidc_portal" {
  label                      = "iac-oidc-portal"
  type                       = "web"
  status                     = "ACTIVE"
  authentication_policy      = local.default_app_signon_policy_id
  grant_types                = ["authorization_code"]
  response_types             = ["code"]
  redirect_uris              = ["https://oidcdebugger.com/debug"]
  token_endpoint_auth_method = "client_secret_basic"
  consent_method             = "REQUIRED"
  issuer_mode                = "DYNAMIC"
  pkce_required              = false
  login_mode                 = "DISABLED" # no initiate_login_uri, so no dashboard tile
  hide_ios                   = true
  hide_web                   = true
  user_name_template         = "$${source.login}"
  user_name_template_type    = "BUILT_IN"
  app_settings_json          = jsonencode({ app = {}, manualProvisioning = false })

  # Import leaves these null in state and the provider then plans its defaults (false, 0, STATIC, false),
  # whether or not they are in config. skip_authentication_policy also conflicts with authentication_policy.
  # Provider 7.0.0 behavior, run 1 finding.
  lifecycle {
    ignore_changes = [omit_secret, refresh_token_leeway, refresh_token_rotation, skip_authentication_policy]
  }
}

resource "okta_app_group_assignments" "iac_oidc_portal" {
  app_id = okta_app_oauth.iac_oidc_portal.id
  group {
    id       = okta_group.it.id
    priority = 0
    profile  = jsonencode({})
  }
}
