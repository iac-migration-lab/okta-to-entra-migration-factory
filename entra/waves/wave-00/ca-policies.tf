# Okta authentication policy iac-authn-saml-apps (okta-inventory/policies-app-signon.tf), translated:
#   finance-2fa (group Finance, two factors) -> this policy
#   office-zone (password in iac-zone-office) and catch-all (password) -> no CA policy; password is the Entra baseline
# New CA policies start report-only; break-glass and owner excluded (CLAUDE.md).
resource "azuread_conditional_access_policy" "lab_ca10" {
  display_name = "${var.ca_prefix}-CA10 - Wave-00 SAML apps - Require MFA - Finance - Any location"
  state        = "enabledForReportingButNotEnforced"

  conditions {
    client_app_types = ["all"]

    applications {
      included_applications = concat(
        [for sp in azuread_service_principal.saml : sp.client_id],
        [azuread_service_principal.it_tools.client_id],
      )
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
