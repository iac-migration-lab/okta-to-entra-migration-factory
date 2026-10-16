resource "okta_auth_server" "iac_authz_api" {
  name                      = "iac-authz-api"
  description               = "Lab API"
  audiences                 = ["api://iac-lab"]
  issuer_mode               = "DYNAMIC"
  credentials_rotation_mode = "AUTO"
  status                    = "ACTIVE"
}

resource "okta_auth_server_scope" "iac_read" {
  auth_server_id   = okta_auth_server.iac_authz_api.id
  name             = "iac.read"
  description      = "Read lab API"
  consent          = "IMPLICIT"
  metadata_publish = "NO_CLIENTS"
  default          = false
  optional         = false
}

resource "okta_auth_server_claim" "department" {
  auth_server_id          = okta_auth_server.iac_authz_api.id
  name                    = "department"
  status                  = "ACTIVE"
  claim_type              = "RESOURCE"
  value_type              = "EXPRESSION"
  value                   = "user.department"
  always_include_in_token = true
}

resource "okta_auth_server_policy" "iac_authz_portal" {
  auth_server_id   = okta_auth_server.iac_authz_api.id
  name             = "iac-authz-portal"
  description      = "Portal client"
  status           = "ACTIVE"
  priority         = 1
  client_whitelist = [okta_app_oauth.iac_oidc_portal.client_id]
}

resource "okta_auth_server_policy_rule" "allow_auth_code" {
  auth_server_id                 = okta_auth_server.iac_authz_api.id
  policy_id                      = okta_auth_server_policy.iac_authz_portal.id
  name                           = "allow-auth-code"
  status                         = "ACTIVE"
  type                           = "RESOURCE_ACCESS"
  priority                       = 1
  grant_type_whitelist           = ["authorization_code"]
  scope_whitelist                = ["*"]
  group_whitelist                = ["EVERYONE"]
  group_blacklist                = []
  user_whitelist                 = []
  user_blacklist                 = []
  access_token_lifetime_minutes  = 60
  refresh_token_lifetime_minutes = 0
  refresh_token_window_minutes   = 10080
}
