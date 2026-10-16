output "saml_apps" {
  value = merge(
    { for k, sp in azuread_service_principal.saml : local.saml_apps[k].name => { client_id = sp.client_id, sp_object_id = sp.object_id } },
    { "iac-saml-it-tools" = { client_id = azuread_service_principal.it_tools.client_id, sp_object_id = azuread_service_principal.it_tools.object_id } },
  )
}

output "oidc_portal_client_id" {
  value = azuread_application.oidc_portal.client_id
}
