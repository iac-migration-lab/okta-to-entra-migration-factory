output "saml_apps" {
  value = {
    (azuread_application.hr_portal.display_name)              = { client_id = azuread_service_principal.hr_portal.client_id, sp_object_id = azuread_service_principal.hr_portal.object_id }
    (azuread_application_from_template.it_tools.display_name) = { client_id = azuread_service_principal.it_tools.client_id, sp_object_id = azuread_service_principal.it_tools.object_id }
  }
}
