# iac-saml-it-tools: low-risk app of wave-01 (docs/wave-01-plan.md). Built in wave-00 and moved here unchanged
# (imports.tf); Okta source okta-inventory/app-iac-saml-it-tools.tf, assigned to the IT group.
resource "azuread_application_from_template" "it_tools" {
  display_name = "${var.name_prefix}-saml-it-tools"
  template_id  = local.non_gallery_template_id
}

resource "azuread_application_identifier_uri" "it_tools" {
  application_id = azuread_application_from_template.it_tools.application_id
  identifier_uri = "https://sptest.iamshowcase.com/${var.name_prefix}-saml-it-tools"

  depends_on = [azuread_service_principal.it_tools] # SAML mode first (wave-00 apps-saml.tf)
}

resource "azuread_application_redirect_uris" "it_tools" {
  application_id = azuread_application_from_template.it_tools.application_id
  type           = "Web"
  redirect_uris  = [local.acs_url]
}

data "azuread_application" "it_tools" {
  object_id = azuread_application_from_template.it_tools.application_object_id
}

resource "azuread_service_principal" "it_tools" {
  client_id                     = data.azuread_application.it_tools.client_id
  use_existing                  = true
  preferred_single_sign_on_mode = "saml"
  app_role_assignment_required  = true

  feature_tags {
    enterprise            = true
    custom_single_sign_on = true
  }
}

resource "azuread_service_principal_token_signing_certificate" "it_tools" {
  service_principal_id = azuread_service_principal.it_tools.id
  display_name         = "CN=${var.name_prefix}-saml-it-tools"
}

resource "azuread_app_role_assignment" "it_tools" {
  resource_object_id  = azuread_service_principal.it_tools.object_id
  principal_object_id = data.azuread_group.staff["it"].object_id
  app_role_id         = one([for r in azuread_service_principal.it_tools.app_roles : r.id if r.display_name == "User"])
}

resource "msgraph_update_resource" "it_tools_active_signing_key" {
  url  = "servicePrincipals/${azuread_service_principal.it_tools.object_id}"
  body = { preferredTokenSigningKeyThumbprint = azuread_service_principal_token_signing_certificate.it_tools.thumbprint }
}

# msgraph customClaimsPolicy (the chosen claims method, findings 2026-10-20). The policy already exists, so the
# one-time create action wave-00 needed is not carried over; the update resource only tracks it.
resource "msgraph_update_resource" "it_tools_claims" {
  api_version = "beta"
  url         = "servicePrincipals/${azuread_service_principal.it_tools.object_id}/claimsPolicy"
  body = {
    includeBasicClaimSet = true
    claims = [
      {
        # Without this the NameID is a pairwise persistent ID; Okta sent the username as emailAddress.
        "@odata.type"  = "#microsoft.graph.samlNameIdClaim"
        nameIdFormat   = "emailAddress"
        configurations = [{ attribute = { "@odata.type" = "#microsoft.graph.sourcedAttribute", id = "userprincipalname", source = "user", isExtensionAttribute = false } }]
      },
      {
        "@odata.type" = "#microsoft.graph.customClaim"
        name          = "department"
        tokenFormat   = ["saml"]
        configurations = [{
          attribute = { "@odata.type" = "#microsoft.graph.sourcedAttribute", id = "department", source = "user", isExtensionAttribute = false }
        }]
      },
    ]
  }
}
