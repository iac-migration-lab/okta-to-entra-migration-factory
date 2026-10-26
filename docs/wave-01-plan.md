# Wave 01 Plan: First Cutover Wave (Run 1, Lab Phase 4)

Planned 2026-10-26. Status: **steps 1 and 2 done 2026-10-26 (PR #14 applied); step 3 done 2026-10-26 (PR #16 applied); step 4 next.** Evidence and results go to [findings-log.md](findings-log.md); this file is the plan of record and is updated only when a decision changes.

## 1. Decision
- **Apps:** `iac-saml-it-tools` (low risk) and `iac-saml-hr-portal` (tier 1).
- **Validation windows:** 2 days for it-tools, 5 days for hr-portal (lab values; production uses 7 and 30, per the plan).
- **Rollback drill:** on it-tools, right after its cutover, timed.
- **Deadline:** done by 2026-11-15; the Entra ID P2 trial lapses 2026-11-16.

## 2. Risk score
Score = active assigned users + 2 per assigned group + 2 per custom claim + 3 if an Okta MFA (multi-factor authentication) rule applies to any assigned user. Source: [okta-seed-spec.md](okta-seed-spec.md) and `okta-inventory/app-*.tf`. Ivan Cole (deactivated leaver) is not counted.

| App (Okta) | Active users | Groups | Custom claims (Okta) | MFA rule hits | Score | Notes |
|---|---|---|---|---|---|---|
| `iac-saml-finance-ledger` | 2 (Gus, Hana) | 1 | 0 | yes (`finance-2fa`) | 7 | Lowest user count, but every user is under the MFA rule |
| `iac-saml-it-tools` | 3 (Ada, Ben, Cara) | 1 | 0 | no | 5 | Lowest score; Entra side already on the chosen claims method (msgraph `customClaimsPolicy`) |
| `iac-saml-custserv-desk` | 4 (Cara, Dev, Eli, Fay) | 1 | 0 | no | 6 | Holds the shared identifier `IAMShowcase` in prod; claims portal-only (invisible to Terraform) |
| `iac-saml-hr-portal` | 8 (all active staff) | 3 | 4 (`department`, `title`, `employeeNumber`, `groups`) | yes (Gus, Hana) | 25 | Highest score: every user, every group, the most claims |
| `iac-oidc-portal` | 3 | 1 | 1 (`department`) | n/a | 7 | OIDC (OpenID Connect); not in scope: the wave plan calls for SAML apps tested against the SAML test SP (service provider) |

**Why these two:** it-tools has the lowest score, and its Entra resources are plain (not `for_each`), so it is the simplest move. hr-portal has the highest score and touches all three groups, the most claims, and Finance MFA, so it is the "tier 1" app. Together they test both move patterns in section 4.

**Left for wave-02:** finance-ledger, custserv-desk (fix the portal-only claims and the shared identifier first), oidc-portal.

## 3. What "cutover" means in the lab
- The test SP (IAM Showcase) accepts IdP-initiated SAML (Security Assertion Markup Language) from any IdP (identity provider), so there is no SP metadata to re-point. In production, cutover also means re-pointing each SP to Entra's metadata; that step is not proven here.
- Cutover = remove the app's **group assignments** in Okta, so the Okta tile disappears and users reach the app only from Entra My Apps. The Okta app itself stays until decommission.
- Rollback = re-create the Okta group assignment.

## 4. How the apps move from wave-00 to wave-01 (no rebuild)
The Entra apps already exist (built and tested in wave-00). They move into the wave-01 state; nothing is destroyed or re-created, so client IDs, signing certificates and identifiers stay the same.

- **wave-00 forgets them:** a `removed` block with `lifecycle { destroy = false }`.
- **wave-01 adopts them:** `import` blocks by object ID.
- **The `for_each` catch (tested 2026-10-26, Terraform 1.16.4, local `terraform_data` test):** a `removed` block cannot name one instance (`Error: Resource instance keys not allowed`). hr-portal sits in the `saml` `for_each` map, so wave-00 needs a `moved` block (instance → plain resource name) and a `removed` block for that name, in the same change. The test plan showed "will no longer be managed by Terraform, but will not be destroyed", 0 to destroy.
- it-tools resources are plain names, so `removed` blocks are enough for all but one: its active signing key is the `it_tools` entry of `msgraph_update_resource.saml_active_signing_key` (a `for_each`), which needs the same `moved` + `removed` pair. The hard-coded `it_tools` entry in the wave-00 `saml_signing` local is deleted.

Objects that move:

| App | Resources (wave-00 address) |
|---|---|
| it-tools | `azuread_application_from_template.it_tools`, `azuread_application_identifier_uri.it_tools`, `azuread_application_redirect_uris.it_tools`, `azuread_service_principal.it_tools`, `azuread_service_principal_token_signing_certificate.it_tools`, `azuread_app_role_assignment.it_tools`, `msgraph_update_resource.it_tools_claims` (re-declared in wave-01; the one-time `msgraph_resource_action.it_tools_claims_create` is not carried over), its `msgraph_update_resource.saml_active_signing_key` entry |
| hr-portal | `azuread_application.saml["hr_portal"]`, `azuread_application_identifier_uri.saml["hr_portal"]`, `azuread_service_principal.saml["hr_portal"]`, `azuread_service_principal_token_signing_certificate.saml["hr_portal"]`, `azuread_app_role_assignment.saml["hr_portal/it"]`, `["hr_portal/custserv"]`, `["hr_portal/finance"]`, `azuread_claims_mapping_policy.hr_portal`, `azuread_service_principal_claims_mapping_policy_assignment.hr_portal`, its `saml_active_signing_key` entry |

- **CA (Conditional Access):** `LAB-CA10` in wave-00 lists the wave-00 SAML apps, so it drops both apps automatically. wave-01 adds `LAB-CA11 - Wave-01 SAML apps - Require MFA - Finance - Any location`, report-only, break-glass and owner excluded, so Finance MFA coverage is never lost.
- **Both copies:** the same move runs for nonprod (`iac-np-*`, `tfstate-nonprod`) and prod.
- UNVERIFIED: whether `msgraph_update_resource` entries (signing key, claims) import cleanly or simply re-apply the same body; expect a one-time "update in place" with no real change. Run 1: try it and log.

## 5. Sequence

| # | Step | Who | Gate | Target date |
|---|---|---|---|---|
| 1 | Create the wave-01 state files (both containers) with the owner's login | Claude (local, logged) | none | 10-27 |
| 2 | Change issue + **PR A: the move.** wave-01 skeleton (copy of wave-00 `data.tf`, `variables.tf`, `providers.tf`, `versions.tf`, `tenants/`), import blocks, `LAB-CA11`; wave-00 `moved` + `removed` blocks. Expected plans: wave-00 "0 to destroy" with objects forgotten; wave-01 only imports plus `LAB-CA11` (1 to add) | Claude; owner approves prod | change gate, Conftest, prod reviewer | 10-27 |
| 3 | Change issue + **PR B: hr-portal claims to msgraph `customClaimsPolicy`** (the 2026-10-20 decision), replacing the claims mapping policy. Adds the `groups` claim, which wave-00 never sent (its mapping policy has `department`, `title`, `employeeNumber` only; Okta sends all four) | Claude; owner approves prod | same | 10-27 |
| 4 | **Test through Entra** (window opens): sign in from My Apps as Ada (it-tools, hr-portal) and Gus (hr-portal; check `department`, `title`, `employeeNumber`, and the `groups` claim added in PR B); Gus refused on it-tools (not assigned); Ivan absent from Entra. Screenshots to `docs/evidence/` | Owner signs in; Claude checks claims | evidence filed | 10-27 |
| 5 | **Okta cutover identity `iac-okta-cutover`:** Okta API service app, private key JWT (JSON Web Token), scope `okta.apps.manage` only; deactivated when not in use. Register row at grant time | Claude (Okta Admin Console click path for the owner if needed) | register row | 10-28 |
| 6 | **Cutover workflow** `okta-cutover.yml`: `workflow_dispatch` with inputs `app`, `action` (`remove` / `restore`); environment `okta-cutover` with the owner as required reviewer; change gate; key from an environment secret; logs the before and after group list | Claude, by PR | change gate, reviewer | 10-28 |
| 7 | **Cut over it-tools** (2-day window ends 10-29): workflow removes the `IT` assignment | Claude runs; owner approves | change issue in window | 10-29 |
| 8 | **Rollback drill on it-tools**, timed from "go" to a user signed in through Okta: workflow `restore`, Ada signs in from the Okta dashboard, workflow `remove` again | Claude + owner | change issue in window | 10-29 |
| 9 | **Cut over hr-portal** (5-day window ends 11-01): remove `IT`, `CustServ`, `Finance` assignments | Claude runs; owner approves | change issue in window | 11-01 or the next session after |
| 10 | **Okta snapshot check:** the next snapshot shows only the assignment removals; then a PR updates `okta-inventory/` to match so the snapshot is green again | Claude | snapshot | day after each cutover |
| 11 | Deactivate `iac-okta-cutover`; findings entry; runbook sections 6 and 7 set to Run 1 | Claude | none | after step 10 |

## 6. Go / no-go for each cutover
- Go only if: the window has run its full length; the step 4 sign-ins passed with evidence; the latest Entra drift run is green; the change issue is `change:implement` and inside its window.
- Roll back if, during the window or after cutover: any assigned user cannot sign in through Entra, a claim is missing or wrong, or an unassigned user gets in.

## 7. Rollback triggers and target
- Target: user back on Okta in under 15 minutes from the decision (measure it in step 8; the plan has no number yet).
- The Entra side is never deleted during rollback; it stays in wave-01 for the next try.

## 8. Open items
- UNVERIFIED: Okta API for app group assignments, `DELETE` and `PUT /api/v1/apps/{appId}/groups/{groupId}`, works with `okta.apps.manage` alone. Try in step 6 and log.
- UNVERIFIED: how the Okta snapshot (plan with `-detailed-exitcode`) reports a removed assignment on `okta_app_group_assignments`; expected exit 2 (drift).
- Gap found while planning: wave-00 hr-portal never sent the Okta `groups` claim. Fixed in PR B; the claims comparison in Lab Phase 2 missed it because it checked the three user attributes only.
- Okta assignment changes outside Terraform will make `okta-inventory/` drift by design; step 10 closes that loop. Run 2 question: should cutover be a Terraform apply of `okta-inventory/` by the cutover identity instead of a script?
