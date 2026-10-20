# Okta OIDC web app iac-oidc-portal translated (okta-inventory/app-iac-oidc-portal.tf).
# Okta: Authorization Code with a client secret. oidcdebugger.com cannot redeem a code, so run 1 proves
# sign-in with an ID token (implicit, form_post) and no secret exists in Entra.
resource "azuread_application" "oidc_portal" {
  display_name     = "${var.name_prefix}-oidc-portal"
  sign_in_audience = "AzureADMyOrg"

  api {
    mapped_claims_enabled = true # lets the claims mapping policy below add department
  }

  web {
    redirect_uris = ["https://oidcdebugger.com/debug"]

    implicit_grant {
      id_token_issuance_enabled = true
    }
  }
}

resource "azuread_service_principal" "oidc_portal" {
  client_id                    = azuread_application.oidc_portal.client_id
  app_role_assignment_required = true

  feature_tags {
    enterprise = true
  }
}

resource "azuread_app_role_assignment" "oidc_portal" {
  resource_object_id  = azuread_service_principal.oidc_portal.object_id
  principal_object_id = data.azuread_group.staff["it"].object_id
  app_role_id         = "00000000-0000-0000-0000-000000000000" # default access; the app defines no roles
}

resource "azuread_claims_mapping_policy" "oidc_portal" {
  display_name = "${var.name_prefix}-cmp-oidc-portal"
  definition = [jsonencode({
    ClaimsMappingPolicy = {
      Version              = 1
      IncludeBasicClaimSet = "true"
      ClaimsSchema         = [{ Source = "user", ID = "department", JwtClaimType = "department" }]
    }
  })]
}

resource "azuread_service_principal_claims_mapping_policy_assignment" "oidc_portal" {
  claims_mapping_policy_id = azuread_claims_mapping_policy.oidc_portal.id
  service_principal_id     = azuread_service_principal.oidc_portal.id
}
