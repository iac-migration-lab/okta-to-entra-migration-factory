# iac-saml-hr-portal: tier 1 app of wave-01 (docs/wave-01-plan.md). Built in wave-00 and moved here unchanged
# (PR #14, import blocks since deleted); Okta source okta-inventory/app-iac-saml-hr-portal.tf, assigned to all three staff groups.
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

  # Okta sends a "groups" attribute (all the user's groups). The custom claims policy has no group claim type
  # (Graph beta $metadata, 2026-10-26), so groups come from the app registration: only groups assigned to the
  # app, as display names (cloud groups have no sAMAccountName). UNVERIFIED until the sign-in test: Entra names
  # the attribute .../claims/groups, not "groups", and the values are iac-it, not Okta's IT.
  group_membership_claims = ["ApplicationGroup"]

  optional_claims {
    saml2_token {
      name                  = "groups"
      additional_properties = ["cloud_displayname"]
    }
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

# Claims through the msgraph customClaimsPolicy (the chosen method, findings 2026-10-20), replacing the wave-00
# claims mapping policy. Same four values as Okta's NameID and attribute statements, groups aside (see above).
locals {
  hr_portal_claims_policy = {
    includeBasicClaimSet = true
    claims = [
      {
        # Okta sends the username as the emailAddress NameID.
        "@odata.type"  = "#microsoft.graph.samlNameIdClaim"
        nameIdFormat   = "emailAddress"
        configurations = [{ attribute = { "@odata.type" = "#microsoft.graph.sourcedAttribute", id = "userprincipalname", source = "user", isExtensionAttribute = false } }]
      },
      {
        "@odata.type"  = "#microsoft.graph.customClaim"
        name           = "department"
        tokenFormat    = ["saml"]
        configurations = [{ attribute = { "@odata.type" = "#microsoft.graph.sourcedAttribute", id = "department", source = "user", isExtensionAttribute = false } }]
      },
      {
        "@odata.type"  = "#microsoft.graph.customClaim"
        name           = "title"
        tokenFormat    = ["saml"]
        configurations = [{ attribute = { "@odata.type" = "#microsoft.graph.sourcedAttribute", id = "jobtitle", source = "user", isExtensionAttribute = false } }]
      },
      {
        "@odata.type"  = "#microsoft.graph.customClaim"
        name           = "employeeNumber"
        tokenFormat    = ["saml"]
        configurations = [{ attribute = { "@odata.type" = "#microsoft.graph.sourcedAttribute", id = "employeeid", source = "user", isExtensionAttribute = false } }]
      },
    ]
  }
}

# GET claimsPolicy is 404 until a policy exists, and msgraph_update_resource reads first, so a one-time PUT
# creates it (same pattern as wave-00 it-tools). The PUT works while the old mapping policy is still assigned
# (tested on iac-np-saml-hr-portal, 2026-10-26), so one apply can switch methods.
resource "msgraph_resource_action" "hr_portal_claims_create" {
  api_version  = "beta"
  resource_url = "servicePrincipals/${azuread_service_principal.hr_portal.object_id}/claimsPolicy"
  method       = "PUT"
  body         = local.hr_portal_claims_policy
}

resource "msgraph_update_resource" "hr_portal_claims" {
  api_version = "beta"
  url         = "servicePrincipals/${azuread_service_principal.hr_portal.object_id}/claimsPolicy"
  body        = local.hr_portal_claims_policy

  depends_on = [msgraph_resource_action.hr_portal_claims_create]
}
