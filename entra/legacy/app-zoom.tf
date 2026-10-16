# Gallery app "Zoom" (template 247d18fc-f848-4de0-8330-333d3a5c0e3f), SSO not configured.
resource "azuread_application" "zoom" {
  display_name            = "iac-legacy-zoom"
  template_id             = "247d18fc-f848-4de0-8330-333d3a5c0e3f"
  sign_in_audience        = "AzureADMyOrg"
  group_membership_claims = ["SecurityGroup"]

  api {
    requested_access_token_version = 2

    oauth2_permission_scope {
      admin_consent_description  = "Allow the application to access iac-legacy-zoom on behalf of the signed-in user"
      admin_consent_display_name = "Access iac-legacy-zoom"
      enabled                    = true
      id                         = "4db35186-2c74-4559-8ba0-e05df6198b3f"
      type                       = "User"
      user_consent_description   = "Allow the application to access iac-legacy-zoom on your behalf."
      user_consent_display_name  = "Access iac-legacy-zoom"
      value                      = "user_impersonation"
    }
  }

  dynamic "app_role" {
    # Roles the gallery template creates; the IDs are fixed by Entra.
    for_each = {
      Basic         = "759e2d92-6615-40fc-aff2-8fc90dc69c6e"
      Collaboration = "9a50c0df-61a7-46c7-8c15-22f797a575d0"
      Corp          = "ee86e454-5f39-4878-8aac-72dd639542de"
      Licensed      = "43469f26-4e68-46db-92c9-786e620cf24a"
      On-Prem       = "4144d0ae-82aa-4089-b26d-6e8e09dec705"
      Pro           = "1cccf8c6-0e95-414e-8fe4-c623d07197fb"
      msiam_access  = "686836a1-866a-4e58-83e4-75a6e5f50cd8"
    }
    content {
      allowed_member_types = ["User"]
      description          = app_role.key
      display_name         = app_role.key
      enabled              = true
      id                   = app_role.value
    }
  }

  web {
    homepage_url  = "https://*.zoom.us/saml/SSO?metadata=zoom|ISV9.1|primary|z"
    redirect_uris = ["https://*.zoom.us/saml/SSO"]
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "azuread_service_principal" "zoom" {
  client_id                    = azuread_application.zoom.client_id
  app_role_assignment_required = true

  feature_tags {
    enterprise = true
  }

  lifecycle {
    prevent_destroy = true
  }
}
