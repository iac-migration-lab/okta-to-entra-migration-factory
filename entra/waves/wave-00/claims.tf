# Claims experiment (build-phases Lab Phase 2 step 6), one mechanism per app:
#   hr-portal      azuread_claims_mapping_policy (Okta: department, title, employeeNumber, groups)
#   it-tools       msgraph customClaimsPolicy, beta (department)
#   custserv-desk  portal only (nothing here)
#   finance-ledger Entra defaults

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
  service_principal_id     = azuread_service_principal.saml["hr_portal"].id
}

# msgraph_update_resource reads before it writes, and GET claimsPolicy is 404 until one exists (PATCH and PUT
# both fail on a new app). So a one-time action creates it, then the update resource tracks it for drift.
locals {
  it_tools_claims_policy = {
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

resource "msgraph_resource_action" "it_tools_claims_create" {
  api_version  = "beta"
  resource_url = "servicePrincipals/${azuread_service_principal.it_tools.object_id}/claimsPolicy"
  method       = "PUT"
  body         = local.it_tools_claims_policy
}

resource "msgraph_update_resource" "it_tools_claims" {
  api_version = "beta"
  url         = "servicePrincipals/${azuread_service_principal.it_tools.object_id}/claimsPolicy"
  body        = local.it_tools_claims_policy

  depends_on = [msgraph_resource_action.it_tools_claims_create]
}
