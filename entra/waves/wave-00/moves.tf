# it-tools and hr-portal moved to entra/waves/wave-01 (docs/wave-01-plan.md). This state forgets them and
# wave-01 imports them (wave-01 imports.tf), so nothing in Entra is destroyed or re-created.
# A removed block cannot name one instance of a for_each resource ("Resource instance keys not allowed"), so each
# instance is first moved to a plain name, then that name is removed (tested 2026-10-26, findings).
# Delete this file once both copies are applied.

# hr-portal: instances of the "saml" for_each map.
moved {
  from = azuread_application.saml["hr_portal"]
  to   = azuread_application.hr_portal_to_wave_01
}
moved {
  from = azuread_application_identifier_uri.saml["hr_portal"]
  to   = azuread_application_identifier_uri.hr_portal_to_wave_01
}
moved {
  from = azuread_service_principal.saml["hr_portal"]
  to   = azuread_service_principal.hr_portal_to_wave_01
}
moved {
  from = azuread_service_principal_token_signing_certificate.saml["hr_portal"]
  to   = azuread_service_principal_token_signing_certificate.hr_portal_to_wave_01
}
moved {
  from = azuread_app_role_assignment.saml["hr_portal/it"]
  to   = azuread_app_role_assignment.hr_portal_it_to_wave_01
}
moved {
  from = azuread_app_role_assignment.saml["hr_portal/custserv"]
  to   = azuread_app_role_assignment.hr_portal_custserv_to_wave_01
}
moved {
  from = azuread_app_role_assignment.saml["hr_portal/finance"]
  to   = azuread_app_role_assignment.hr_portal_finance_to_wave_01
}
moved {
  from = msgraph_update_resource.saml_active_signing_key["hr_portal"]
  to   = msgraph_update_resource.hr_portal_active_signing_key_to_wave_01
}
moved {
  from = msgraph_update_resource.saml_active_signing_key["it_tools"]
  to   = msgraph_update_resource.it_tools_active_signing_key_to_wave_01
}

removed {
  from = azuread_application.hr_portal_to_wave_01
  lifecycle { destroy = false }
}
removed {
  from = azuread_application_identifier_uri.hr_portal_to_wave_01
  lifecycle { destroy = false }
}
removed {
  from = azuread_service_principal.hr_portal_to_wave_01
  lifecycle { destroy = false }
}
removed {
  from = azuread_service_principal_token_signing_certificate.hr_portal_to_wave_01
  lifecycle { destroy = false }
}
removed {
  from = azuread_app_role_assignment.hr_portal_it_to_wave_01
  lifecycle { destroy = false }
}
removed {
  from = azuread_app_role_assignment.hr_portal_custserv_to_wave_01
  lifecycle { destroy = false }
}
removed {
  from = azuread_app_role_assignment.hr_portal_finance_to_wave_01
  lifecycle { destroy = false }
}
removed {
  from = msgraph_update_resource.hr_portal_active_signing_key_to_wave_01
  lifecycle { destroy = false }
}
removed {
  from = msgraph_update_resource.it_tools_active_signing_key_to_wave_01
  lifecycle { destroy = false }
}

# hr-portal claims, and it-tools: plain resources, removed directly.
removed {
  from = azuread_claims_mapping_policy.hr_portal
  lifecycle { destroy = false }
}
removed {
  from = azuread_service_principal_claims_mapping_policy_assignment.hr_portal
  lifecycle { destroy = false }
}
removed {
  from = azuread_application_from_template.it_tools
  lifecycle { destroy = false }
}
removed {
  from = azuread_application_identifier_uri.it_tools
  lifecycle { destroy = false }
}
removed {
  from = azuread_application_redirect_uris.it_tools
  lifecycle { destroy = false }
}
removed {
  from = azuread_service_principal.it_tools
  lifecycle { destroy = false }
}
removed {
  from = azuread_service_principal_token_signing_certificate.it_tools
  lifecycle { destroy = false }
}
removed {
  from = azuread_app_role_assignment.it_tools
  lifecycle { destroy = false }
}
removed {
  from = msgraph_update_resource.it_tools_claims
  lifecycle { destroy = false }
}
removed {
  from = msgraph_resource_action.it_tools_claims_create # one-time create; wave-01 does not need it
  lifecycle { destroy = false }
}
