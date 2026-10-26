# Adopt the it-tools and hr-portal objects that wave-00 built (wave-00 moves.tf forgets them in the same change).
# IDs read from the wave-00 state on 2026-10-26. Kept after the first apply (an import of an object already in
# state is a no-op); delete this file once both copies are applied. Porting: docs/porting-guide.md.
locals {
  wave_00_ids = {
    "lab" = {
      hr_app             = "/applications/eecf2152-29e4-4af4-830d-408591a4ab00"
      hr_identifier      = "/applications/eecf2152-29e4-4af4-830d-408591a4ab00/identifierUris/aHR0cHM6Ly9zcHRlc3QuaWFtc2hvd2Nhc2UuY29tL2lhYy1zYW1sLWhyLXBvcnRhbA=="
      hr_sp              = "/servicePrincipals/8e9387a0-7f1f-4171-8c41-0f6b869d746e"
      hr_cert            = "8e9387a0-7f1f-4171-8c41-0f6b869d746e/tokenSigningCertificate/0eb8113b-99c4-4406-9551-4ee10d78984c"
      hr_assign_it       = "/servicePrincipals/8e9387a0-7f1f-4171-8c41-0f6b869d746e/appRoleAssignedTo/QRH47HM7_0qSpkUqFwZDpdDxjO0rUrRHi2oUjTo1edg"
      hr_assign_custserv = "/servicePrincipals/8e9387a0-7f1f-4171-8c41-0f6b869d746e/appRoleAssignedTo/UdZC-3IxCE-nD-CqNgJRBD-EIDMcwX9LgMLuzzHC8QY"
      hr_assign_finance  = "/servicePrincipals/8e9387a0-7f1f-4171-8c41-0f6b869d746e/appRoleAssignedTo/qmzvTgIpeUmCKDj9CL_o_0wcEdjsSL9BrbJTZmkm3mU"
      hr_cmp             = "/policies/claimsMappingPolicies/ca950aa4-e886-47bb-9f75-7e514e826d37"
      hr_cmp_assign      = "/servicePrincipals/8e9387a0-7f1f-4171-8c41-0f6b869d746e/claimsMappingPolicies/ca950aa4-e886-47bb-9f75-7e514e826d37"
      it_app             = "/applicationTemplates/8adf8e6e-67b2-4cf2-a259-e3dc5476c621/instantiate/ffb63dab-e312-4f8e-af20-3d94b36de01a/eb31580a-56d2-466d-851b-5dea48ca489a"
      it_identifier      = "/applications/ffb63dab-e312-4f8e-af20-3d94b36de01a/identifierUris/aHR0cHM6Ly9zcHRlc3QuaWFtc2hvd2Nhc2UuY29tL2lhYy1zYW1sLWl0LXRvb2xz"
      it_redirect_uris   = "/applications/ffb63dab-e312-4f8e-af20-3d94b36de01a/redirectUris/Web"
      it_sp              = "/servicePrincipals/eb31580a-56d2-466d-851b-5dea48ca489a"
      it_cert            = "eb31580a-56d2-466d-851b-5dea48ca489a/tokenSigningCertificate/391a7dfb-3f1a-47cc-bb10-633eb71690da"
      it_assign_it       = "/servicePrincipals/eb31580a-56d2-466d-851b-5dea48ca489a/appRoleAssignedTo/QRH47HM7_0qSpkUqFwZDpcvhus6Z8DpBuOnE1h_Kmow"
    }
    "lab-np" = {
      hr_app             = "/applications/58f0f8e5-d360-4037-b94d-c511075997eb"
      hr_identifier      = "/applications/58f0f8e5-d360-4037-b94d-c511075997eb/identifierUris/aHR0cHM6Ly9zcHRlc3QuaWFtc2hvd2Nhc2UuY29tL2lhYy1ucC1zYW1sLWhyLXBvcnRhbA=="
      hr_sp              = "/servicePrincipals/c74c396f-b175-4bd6-a47a-2f1053030db1"
      hr_cert            = "c74c396f-b175-4bd6-a47a-2f1053030db1/tokenSigningCertificate/467e1986-cfef-4b40-8f2f-e158f7562e46"
      hr_assign_it       = "/servicePrincipals/c74c396f-b175-4bd6-a47a-2f1053030db1/appRoleAssignedTo/ff7uuWsSeU-rS8uUOAj36ioycyIjL0xJrAcKCPSzzVk"
      hr_assign_custserv = "/servicePrincipals/c74c396f-b175-4bd6-a47a-2f1053030db1/appRoleAssignedTo/FT_qVuZz-kGvS9vA1xlxQx2YRj795h5MjJHN9lSBpCo"
      hr_assign_finance  = "/servicePrincipals/c74c396f-b175-4bd6-a47a-2f1053030db1/appRoleAssignedTo/UJS-Lq51J0KBGSfzjfHB2IgMrfTBLtNAi_Y_Fw5T9lw"
      hr_cmp             = "/policies/claimsMappingPolicies/27ae7cfb-df4e-4f64-8aa6-6188526af30d"
      hr_cmp_assign      = "/servicePrincipals/c74c396f-b175-4bd6-a47a-2f1053030db1/claimsMappingPolicies/27ae7cfb-df4e-4f64-8aa6-6188526af30d"
      it_app             = "/applicationTemplates/8adf8e6e-67b2-4cf2-a259-e3dc5476c621/instantiate/63552dd6-ea04-42b6-9ca5-d4d9899cab28/c9c2fc30-3604-43da-9c33-439e466f9589"
      it_identifier      = "/applications/63552dd6-ea04-42b6-9ca5-d4d9899cab28/identifierUris/aHR0cHM6Ly9zcHRlc3QuaWFtc2hvd2Nhc2UuY29tL2lhYy1ucC1zYW1sLWl0LXRvb2xz"
      it_redirect_uris   = "/applications/63552dd6-ea04-42b6-9ca5-d4d9899cab28/redirectUris/Web"
      it_sp              = "/servicePrincipals/c9c2fc30-3604-43da-9c33-439e466f9589"
      it_cert            = "c9c2fc30-3604-43da-9c33-439e466f9589/tokenSigningCertificate/b2299e20-3e48-4ff4-8252-95b1abcedd12"
      it_assign_it       = "/servicePrincipals/c9c2fc30-3604-43da-9c33-439e466f9589/appRoleAssignedTo/ff7uuWsSeU-rS8uUOAj36jzGc5-LWg5InJImTQDL9I8"
    }
  }
  ids = local.wave_00_ids[var.tenant_key]
}

import {
  to = azuread_application.hr_portal
  id = local.ids.hr_app
}

import {
  to = azuread_application_identifier_uri.hr_portal
  id = local.ids.hr_identifier
}

import {
  to = azuread_service_principal.hr_portal
  id = local.ids.hr_sp
}

import {
  to = azuread_service_principal_token_signing_certificate.hr_portal
  id = local.ids.hr_cert
}

import {
  to = azuread_app_role_assignment.hr_portal["it"]
  id = local.ids.hr_assign_it
}

import {
  to = azuread_app_role_assignment.hr_portal["custserv"]
  id = local.ids.hr_assign_custserv
}

import {
  to = azuread_app_role_assignment.hr_portal["finance"]
  id = local.ids.hr_assign_finance
}

import {
  to = azuread_claims_mapping_policy.hr_portal
  id = local.ids.hr_cmp
}

import {
  to = azuread_service_principal_claims_mapping_policy_assignment.hr_portal
  id = local.ids.hr_cmp_assign
}

import {
  to = azuread_application_from_template.it_tools
  id = local.ids.it_app
}

import {
  to = azuread_application_identifier_uri.it_tools
  id = local.ids.it_identifier
}

import {
  to = azuread_application_redirect_uris.it_tools
  id = local.ids.it_redirect_uris
}

import {
  to = azuread_service_principal.it_tools
  id = local.ids.it_sp
}

import {
  to = azuread_service_principal_token_signing_certificate.it_tools
  id = local.ids.it_cert
}

import {
  to = azuread_app_role_assignment.it_tools
  id = local.ids.it_assign_it
}
