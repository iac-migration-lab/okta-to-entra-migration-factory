resource "okta_policy_password" "iac_pwd_staff" {
  name            = "iac-pwd-staff"
  description     = "Lab staff password policy"
  status          = "ACTIVE"
  priority        = 1
  auth_provider   = "OKTA"
  groups_included = local.staff_group_ids

  password_min_length            = 12
  password_min_lowercase         = 1
  password_min_uppercase         = 1
  password_min_number            = 1
  password_min_symbol            = 0
  password_exclude_username      = true
  password_dictionary_lookup     = false
  password_history_count         = 4
  password_max_age_days          = 0
  password_expire_warn_days      = 0
  password_min_age_minutes       = 0
  password_max_lockout_attempts  = 10
  password_auto_unlock_minutes   = 0
  password_show_lockout_failures = false
  skip_unlock                    = false

  # Recovery: email only. Identity Engine needs the full set stated (findings 2026-10-16).
  email_recovery       = "ACTIVE"
  recovery_email_token = 60
  question_recovery    = "INACTIVE"
  question_min_length  = 4
  sms_recovery         = "INACTIVE"
  call_recovery        = "INACTIVE"

  breached_password_expire_after_days    = 0
  breached_password_logout_enabled       = false
  password_lockout_notification_channels = []
}

resource "okta_policy_rule_password" "iac_pwd_staff_rule" {
  policy_id          = okta_policy_password.iac_pwd_staff.id
  name               = "iac-pwd-staff-rule"
  status             = "ACTIVE"
  priority           = 1
  network_connection = "ANYWHERE"
  network_includes   = []
  network_excludes   = []
  users_included     = []
  users_excluded     = []
  password_change    = "ALLOW"
  password_reset     = "ALLOW"
  password_unlock    = "DENY"

  password_reset_requirement {
    primary_methods = ["email"]
    step_up_enabled = false
    step_up_methods = []
  }
}
