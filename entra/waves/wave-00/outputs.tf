output "saml_apps" {
  value = { for k, sp in azuread_service_principal.saml : local.saml_apps[k].name => { client_id = sp.client_id, sp_object_id = sp.object_id } }
}

output "oidc_portal_client_id" {
  value = azuread_application.oidc_portal.client_id
}
