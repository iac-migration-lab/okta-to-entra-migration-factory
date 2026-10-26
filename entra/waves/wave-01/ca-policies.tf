# Okta authentication policy iac-authn-saml-apps, rule finance-2fa (group Finance, two factors), for the wave-01
# apps. LAB-CA10 in wave-00 covers the SAML apps still there; this keeps the moved apps covered.
# New CA policies start report-only; break-glass and owner excluded (CLAUDE.md).
resource "azuread_conditional_access_policy" "lab_ca11" {
  display_name = "${var.ca_prefix}-CA11 - Wave-01 SAML apps - Require MFA - Finance - Any location"
  state        = "enabledForReportingButNotEnforced"

  conditions {
    client_app_types = ["all"]

    applications {
      included_applications = [
        azuread_service_principal.hr_portal.client_id,
        azuread_service_principal.it_tools.client_id,
      ]
    }

    users {
      included_groups = [data.azuread_group.staff["finance"].object_id]
      excluded_groups = [local.bg_ca_exclusion_group_id]
      excluded_users  = [local.owner_user_id]
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["mfa"]
  }
}
