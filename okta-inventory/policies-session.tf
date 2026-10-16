resource "okta_policy_signon" "iac_gsp_staff" {
  name            = "iac-gsp-staff"
  description     = "Lab staff sessions"
  status          = "ACTIVE"
  priority        = 1
  groups_included = local.staff_group_ids
}

resource "okta_policy_rule_signon" "iac_gsp_staff_rule" {
  policy_id           = okta_policy_signon.iac_gsp_staff.id
  name                = "iac-gsp-staff-rule"
  status              = "ACTIVE"
  priority            = 1
  access              = "ALLOW"
  authtype            = "ANY"
  identity_provider   = "ANY"
  network_connection  = "ANYWHERE"
  primary_factor      = "PASSWORD_IDP_ANY_FACTOR"
  mfa_required        = false
  mfa_lifetime        = 0
  mfa_remember_device = false
  session_idle        = 120 # 2 hours
  session_lifetime    = 480 # 8 hours
  session_persistent  = false
  behaviors           = []
  users_excluded      = []
}
