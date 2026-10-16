# Okta custom SAML apps translated (okta-inventory/app-iac-saml-*.tf).
# Okta lets all four share the audience IAMShowcase; Entra identifiers must be unique in the tenant,
# so only one app can carry it (findings 2026-10-16).
# Order matters: the tenant's default app management policy blocks identifiers without a verified domain,
# tenant ID or app ID, except on SAML apps (excludeSaml). So the service principal is switched to SAML
# first, then the identifier is added as its own resource.

locals {
  saml_apps = {
    custserv_desk = {
      name       = "iac-saml-custserv-desk"
      identifier = "IAMShowcase"
      groups     = ["custserv"]
    }
    finance_ledger = {
      name       = "iac-saml-finance-ledger"
      identifier = "https://sptest.iamshowcase.com/iac-saml-finance-ledger"
      groups     = ["finance"]
    }
    hr_portal = {
      name       = "iac-saml-hr-portal"
      identifier = "https://sptest.iamshowcase.com/iac-saml-hr-portal"
      groups     = ["it", "custserv", "finance"]
    }
  }

  saml_user_role_id = "18d14569-c3bd-439b-9a66-3a2aee01d14f"

  saml_assignments = merge([
    for k, a in local.saml_apps : { for g in a.groups : "${k}/${g}" => { app = k, group = g } }
  ]...)
}

# Three apps through azuread_application with template_id ...
resource "azuread_application" "saml" {
  for_each = local.saml_apps

  display_name     = each.value.name
  template_id      = local.non_gallery_template_id
  sign_in_audience = "AzureADMyOrg"

  # The template creates "User" and "msiam_access"; azuread_application deletes any role not in config,
  # so the one role used for assignments is declared (its ID is the same in every non-gallery app).
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
    ignore_changes = [identifier_uris] # managed by azuread_application_identifier_uri.saml
  }
}

resource "azuread_application_identifier_uri" "saml" {
  for_each = local.saml_apps

  application_id = azuread_application.saml[each.key].id
  identifier_uri = each.value.identifier

  depends_on = [azuread_service_principal.saml]
}

resource "azuread_service_principal" "saml" {
  for_each = local.saml_apps

  client_id                     = azuread_application.saml[each.key].client_id
  use_existing                  = true # the template already created it
  preferred_single_sign_on_mode = "saml"
  app_role_assignment_required  = true

  feature_tags {
    enterprise            = true
    custom_single_sign_on = true
  }
}

resource "azuread_service_principal_token_signing_certificate" "saml" {
  for_each = local.saml_apps

  service_principal_id = azuread_service_principal.saml[each.key].id
  display_name         = "CN=${each.value.name}"
}

resource "azuread_app_role_assignment" "saml" {
  for_each = local.saml_assignments

  resource_object_id  = azuread_service_principal.saml[each.value.app].object_id
  principal_object_id = data.azuread_group.staff[each.value.group].object_id
  app_role_id         = local.saml_user_role_id
}

# ... and one through azuread_application_from_template, to compare the two (build-phases step 5).
resource "azuread_application_from_template" "it_tools" {
  display_name = "iac-saml-it-tools"
  template_id  = local.non_gallery_template_id
}

resource "azuread_application_identifier_uri" "it_tools" {
  application_id = azuread_application_from_template.it_tools.application_id
  identifier_uri = "https://sptest.iamshowcase.com/iac-saml-it-tools"

  depends_on = [azuread_service_principal.it_tools] # SAML mode first (see top of file)
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
  display_name         = "CN=iac-saml-it-tools"
}

resource "azuread_app_role_assignment" "it_tools" {
  resource_object_id  = azuread_service_principal.it_tools.object_id
  principal_object_id = data.azuread_group.staff["it"].object_id
  app_role_id         = one([for r in azuread_service_principal.it_tools.app_roles : r.id if r.display_name == "User"])
}

# azuread 3.10.0 creates the signing certificate but cannot make it active (no preferredTokenSigningKeyThumbprint
# on azuread_service_principal). Without it Entra has no active SAML signing key. Gap filled with msgraph.
locals {
  saml_signing = merge(
    { for k, sp in azuread_service_principal.saml : k => { sp = sp.object_id, thumbprint = azuread_service_principal_token_signing_certificate.saml[k].thumbprint } },
    { it_tools = { sp = azuread_service_principal.it_tools.object_id, thumbprint = azuread_service_principal_token_signing_certificate.it_tools.thumbprint } },
  )
}

resource "msgraph_update_resource" "saml_active_signing_key" {
  for_each = local.saml_signing

  url  = "servicePrincipals/${each.value.sp}"
  body = { preferredTokenSigningKeyThumbprint = each.value.thumbprint }
}
