# Entra waves

Per-wave app migrations, one state key per wave (`entra/waves/<wave>/terraform.tfstate` in `tfstate-prod`). Each wave moves apps from Okta to Entra, then the Okta cutover identity `iac-okta-cutover` removes the Okta assignments (not the apps).

## wave-00 (Lab Phase 2)
| File | Objects |
|---|---|
| `apps-saml.tf` | 4 SAML apps from the non-gallery template (3 via `azuread_application` + `template_id`, it-tools via `azuread_application_from_template`), signing certificates, active key via msgraph, group assignments |
| `claims.tf` | Claims experiment: hr-portal claims mapping policy, it-tools msgraph `customClaimsPolicy` (beta), custserv-desk portal only, finance-ledger defaults |
| `app-oidc.tf` | `iac-oidc-portal` with a claims mapping policy for `department` |
| `ca-policies.tf` | `LAB-CA10` (Okta authentication policy `iac-authn-saml-apps`, Finance rule), report-only |

Two copies in the one lab tenant, selected by `tenant_key`: `lab` (prod, names `iac-*`, `LAB-CA*`, state `tfstate-prod`) and `lab-np` (nonprod, names `iac-np-*`, `LAB-NP-CA*`, state `tfstate-nonprod`). From Lab Phase 3, changes go through `plan.yml` and `apply.yml` only. Providers: hashicorp/azuread 3.10.0, microsoft/msgraph 0.5.0 (preview).
