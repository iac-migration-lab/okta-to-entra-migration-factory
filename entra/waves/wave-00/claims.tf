# Claims experiment (build-phases Lab Phase 2 step 6), one mechanism per app:
#   hr-portal      azuread_claims_mapping_policy (department, title, employeeNumber; Okta also sent groups)
#   it-tools       msgraph customClaimsPolicy, beta (department)
#   custserv-desk  portal only (nothing here)
#   finance-ledger Entra defaults
# Result 2026-10-20 (findings): portal edits are blocked on hr-portal, seen field by field on it-tools (plan wants
# them back), and invisible on custserv-desk. Decision: msgraph customClaimsPolicy for SAML claims.
#
# hr-portal and it-tools, with their claims resources, moved to entra/waves/wave-01 on 2026-10-26 (moves.tf).
# Nothing is left in this file; custserv-desk and finance-ledger get code-managed claims in their own wave.
