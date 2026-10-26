# iac-saml-hr-portal: tier 1 app of wave-01 (docs/wave-01-plan.md). Built in wave-00 and moved here unchanged
# (imports.tf); Okta source okta-inventory/app-iac-saml-hr-portal.tf, assigned to all three staff groups.
# Same shape as the wave-00 "saml" resources, written for one app instead of a for_each map.
resource "azuread_application" "hr_portal" {
  display_name     = "${var.name_prefix}-saml-hr-portal"
  template_id      = local.non_gallery_template_id
  sign_in_audience = "AzureADMyOrg"

  # The template creates "User" and "msiam_access"; azuread_application deletes any role not in config,
  # so the one role used for assignments is declared.
  app_role {
    allowed_member_types = ["User"]
    description          = "User"
    display_name         = "User"
    enabled              = true
    id                   = local.saml_user_role_id
  }

  web {
    redirect_uris = [local.acs_url]
  }

  lifecycle {
    ignore_changes = [identifier_uris] # managed by azuread_application_identifier_uri.hr_portal
  }
}

resource "azuread_application_identifier_uri" "hr_portal" {
  application_id = azuread_application.hr_portal.id
  identifier_uri = "https://sptest.iamshowcase.com/${var.name_prefix}-saml-hr-portal"

  depends_on = [azuread_service_principal.hr_portal] # SAML mode first (wave-00 apps-saml.tf)
}

resource "azuread_service_principal" "hr_portal" {
  client_id                     = azuread_application.hr_portal.client_id
  use_existing                  = true
  preferred_single_sign_on_mode = "saml"
  app_role_assignment_required  = true

  feature_tags {
    enterprise            = true
    custom_single_sign_on = true
  }
}

resource "azuread_service_principal_token_signing_certificate" "hr_portal" {
  service_principal_id = azuread_service_principal.hr_portal.id
  display_name         = "CN=${var.name_prefix}-saml-hr-portal"
}

resource "azuread_app_role_assignment" "hr_portal" {
  for_each = toset(["it", "custserv", "finance"])

  resource_object_id  = azuread_service_principal.hr_portal.object_id
  principal_object_id = data.azuread_group.staff[each.key].object_id
  app_role_id         = local.saml_user_role_id
}

# azuread 3.10.0 cannot make the signing certificate active; msgraph does (wave-00 apps-saml.tf).
resource "msgraph_update_resource" "hr_portal_active_signing_key" {
  url  = "servicePrincipals/${azuread_service_principal.hr_portal.object_id}"
  body = { preferredTokenSigningKeyThumbprint = azuread_service_principal_token_signing_certificate.hr_portal.thumbprint }
}

# Claims mapping policy as built in wave-00 (claims experiment method A). Moves to the msgraph customClaimsPolicy,
# with the missing Okta "groups" claim, in the next wave-01 PR (docs/wave-01-plan.md step 3).
resource "azuread_claims_mapping_policy" "hr_portal" {
  display_name = "${var.name_prefix}-cmp-hr-portal"
  definition = [jsonencode({
    ClaimsMappingPolicy = {
      Version              = 1
      IncludeBasicClaimSet = "true"
      ClaimsSchema = [
        { Source = "user", ID = "userprincipalname", SamlClaimType = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier", SamlNameIdFormat = "urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress" },
        { Source = "user", ID = "department", SamlClaimType = "department" },
        { Source = "user", ID = "jobtitle", SamlClaimType = "title" },
        { Source = "user", ID = "employeeid", SamlClaimType = "employeeNumber" },
      ]
    }
  })]
}

resource "azuread_service_principal_claims_mapping_policy_assignment" "hr_portal" {
  claims_mapping_policy_id = azuread_claims_mapping_policy.hr_portal.id
  service_principal_id     = azuread_service_principal.hr_portal.id
}
