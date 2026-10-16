# Every policy excludes bg-ca-exclusion and the owner account (CLAUDE.md; Conftest rule in Lab Phase 3).

# Built in the portal with "All users", not the Global Administrator role the name says; kept as found.
resource "azuread_conditional_access_policy" "lab_ca01" {
  display_name = "LAB-CA01 - All apps - Require MFA - Admins - Any location"
  state        = "enabled"

  conditions {
    client_app_types = ["all"]

    applications {
      included_applications = ["All"]
    }

    users {
      included_users  = ["All"]
      excluded_groups = [local.bg_ca_exclusion_group_id]
      excluded_users  = [local.owner_user_id]
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["mfa"]
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "azuread_conditional_access_policy" "lab_ca02" {
  display_name = "LAB-CA02 - All apps - Block - All users - Legacy auth"
  state        = "enabled"

  conditions {
    client_app_types = ["exchangeActiveSync", "other"]

    applications {
      included_applications = ["All"]
    }

    users {
      included_users  = ["All"]
      excluded_groups = [local.bg_ca_exclusion_group_id]
      excluded_users  = [local.owner_user_id]
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["block"]
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "azuread_conditional_access_policy" "lab_ca03" {
  display_name = "LAB-CA03 - Office 365 - Auth strength - Finance users - Outside office"
  state        = "enabledForReportingButNotEnforced"

  conditions {
    client_app_types = ["all"]

    applications {
      included_applications = ["Office365"]
    }

    locations {
      included_locations = ["All"]
      excluded_locations = [basename(azuread_named_location.office.id)] # CA wants the bare GUID; the resource ID is a Graph path
    }

    users {
      included_groups = [azuread_group.finance_users.object_id]
      excluded_groups = [local.bg_ca_exclusion_group_id]
      excluded_users  = [local.owner_user_id]
    }
  }

  grant_controls {
    operator                          = "OR"
    authentication_strength_policy_id = azuread_authentication_strength_policy.authenticator_or_fido2.id
  }

  lifecycle {
    prevent_destroy = true
  }
}
