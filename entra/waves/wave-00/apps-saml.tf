# Okta custom SAML apps translated (okta-inventory/app-iac-saml-*.tf).
# Okta lets all four share the audience IAMShowcase; Entra identifiers must be unique in the tenant,
# so only one app can carry it (findings 2026-10-16).
# Order matters: the tenant's default app management policy blocks identifiers without a verified domain,
# tenant ID or app ID, except on SAML apps (excludeSaml). So the service principal is switched to SAML
# first, then the identifier is added as its own resource.

locals {
  saml_apps = {
    custserv_desk = {
      name       = "${var.name_prefix}-saml-custserv-desk"
      identifier = var.use_shared_audience ? "IAMShowcase" : "https://sptest.iamshowcase.com/${var.name_prefix}-saml-custserv-desk"
      groups     = ["custserv"]
    }
    finance_ledger = {
      name       = "${var.name_prefix}-saml-finance-ledger"
      identifier = "https://sptest.iamshowcase.com/${var.name_prefix}-saml-finance-ledger"
      groups     = ["finance"]
    }
  }

  saml_user_role_id = "18d14569-c3bd-439b-9a66-3a2aee01d14f"

  saml_assignments = merge([
    for k, a in local.saml_apps : { for g in a.groups : "${k}/${g}" => { app = k, group = g } }
  ]...)
}

# The apps through azuread_application with template_id. (it-tools, built with azuread_application_from_template
# to compare the two, and hr-portal moved to entra/waves/wave-01 on 2026-10-26 by PR #14.)
# Instantiating the template also adds a user_impersonation OAuth2 scope ("TERRAFORM_INSTANTIATE_<guid>") that
# this config does not declare, so the first apply leaves a diff; the pipeline's post-apply plan applies once more
# to remove it (.github/scripts/tf-roots.sh, findings 2026-10-20).
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

# azuread 3.10.0 creates the signing certificate but cannot make it active (no preferredTokenSigningKeyThumbprint
# on azuread_service_principal). Without it Entra has no active SAML signing key. Gap filled with msgraph.
locals {
  saml_signing = {
    for k, sp in azuread_service_principal.saml : k => { sp = sp.object_id, thumbprint = azuread_service_principal_token_signing_certificate.saml[k].thumbprint }
  }
}

resource "msgraph_update_resource" "saml_active_signing_key" {
  for_each = local.saml_signing

  url  = "servicePrincipals/${each.value.sp}"
  body = { preferredTokenSigningKeyThumbprint = each.value.thumbprint }
}
