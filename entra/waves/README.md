# Entra Waves: App Migrations in Batches

## What this folder is for

Apps move from Okta to Entra in **waves**: small batches that are built, tested and cut over together, so a problem affects a few apps rather than all of them. Each wave is its own folder with its own state file, so one wave can be planned, applied or rolled back without touching another.

A wave goes through these steps ([docs/migration-runbook.md](../../docs/migration-runbook.md) has the full checklist):

| Step | What happens | Where |
|---|---|---|
| 1. Plan | Pick the apps; read their Okta settings from `okta-inventory/` | Change ticket |
| 2. Build | Write the Entra version of each app here; the pipeline creates it. Okta still serves users | Pull request → `apply.yml` |
| 3. Test | Sign in through Entra (My Apps for SAML, a test client for OIDC), check claims, check an unassigned user is refused | Evidence in `docs/evidence/` |
| 4. Cutover | Remove the apps' group assignments in Okta, so users can only reach them through Entra. Done by the Okta identity `iac-okta-cutover` | Lab Phase 4 (not yet run) |
| 5. Rollback (if needed) | Put the Okta assignments back | Lab Phase 4 drill |
| 6. Decommission | After a quiet period, retire the Okta app | Later run |

SAML is Security Assertion Markup Language; OIDC is OpenID Connect. Both are sign-in standards that apps use to trust an identity provider.

## wave-00 (Lab Phase 2): all five custom apps, built and tested, not cut over

wave-00 holds every custom app from the lab Okta org. It proved the build and test steps. `it-tools` and `hr-portal` move to `wave-01` in PR #14 (2026-10-26); the tables below describe wave-00 as built.

| File | What it builds | Okta source |
|---|---|---|
| `apps-saml.tf` | 4 SAML apps: `iac-saml-custserv-desk`, `iac-saml-finance-ledger`, `iac-saml-hr-portal`, `iac-saml-it-tools`. Each gets a signing certificate (made active through msgraph), its identifier, and group assignments | `okta-inventory/app-iac-saml-*.tf` |
| `app-oidc.tf` | OIDC app `iac-oidc-portal`, assigned to `iac-it`, with a claims mapping policy that adds `department` to the token | `okta-inventory/app-iac-oidc-portal.tf` |
| `claims.tf` | The claims experiment: a different way to send SAML claims on each app (below) | Attribute statements on the Okta SAML apps |
| `ca-policies.tf` | `LAB-CA10 - Wave-00 SAML apps - Require MFA - Finance - Any location`, report-only | Okta authentication policy `iac-authn-saml-apps`, rule `finance-2fa` |
| `data.tf` | Looks up the staff groups from `entra/platform` by name; break-glass and owner IDs; the Entra non-gallery app template ID; the test service's sign-in URL | |
| `outputs.tf` | Client IDs and service principal IDs of every app | |
| `variables.tf` + `tenants/*.tfvars` | `tenant_key`, `tenant_id`, `name_prefix` (`iac` / `iac-np`), `ca_prefix` (`LAB` / `LAB-NP`), `use_shared_audience` | |
| `backend.tf`, `providers.tf`, `versions.tf` | State `entra/waves/wave-00/terraform.tfstate`; `hashicorp/azuread` 3.10.0 and `microsoft/msgraph` 0.5.0 | |

### Test targets
- SAML apps sign in to a public test service, IAM Showcase (`https://sptest.iamshowcase.com/acs`), which shows the claims it received.
- The OIDC app redirects to `https://oidcdebugger.com/debug`. Because that site cannot redeem an authorization code, the lab tests with an ID token returned directly (implicit flow, `form_post`). **Lab only:** production apps use authorization code with PKCE (Proof Key for Code Exchange), and the portal shows a warning about the implicit flow.

### The claims experiment and its result
Claims are the user details (department, title, employee number) an app receives at sign-in. wave-00 tried one method per app to see which one Terraform can keep under control:

| App | Method | What happened when someone edited claims in the portal |
|---|---|---|
| `hr-portal` | `azuread_claims_mapping_policy` | Portal editing locked; the portal page shows default claims, not the real ones |
| `it-tools` | msgraph `customClaimsPolicy` (Graph beta) | Portal edits visible field by field; the next plan put them back. **Chosen method** |
| `custserv-desk` | Portal only | Invisible to Terraform |
| `finance-ledger` | Entra defaults | Baseline |

Decision (2026-10-20): use the msgraph `customClaimsPolicy` for SAML claims in later waves.

### Workarounds in the code (and why)
- **Identifier order.** The tenant's default app policy rejects identifiers that are not on a verified domain, except on SAML apps. So each service principal is switched to SAML first, then the identifier is added as its own resource.
- **One shared identifier.** Okta let all four apps share the audience `IAMShowcase`; Entra needs identifiers unique in the tenant. Only `custserv-desk` in prod uses it (`use_shared_audience = true`); the others use a unique URL.
- **The "User" app role is declared** because `azuread_application` deletes template roles that the code does not list, which broke assignments.
- **Active signing key through msgraph.** azuread 3.10.0 creates the SAML signing certificate but cannot make it the active one.
- **The extra `user_impersonation` scope.** Creating an app from the template adds a scope the code does not declare, so the first apply leaves a difference. The pipeline's post-apply check applies once more to remove it.
- **Two ways to create from the template, compared:** three apps use `azuread_application` with `template_id`; `it-tools` uses `azuread_application_from_template`.

## wave-01 (Lab Phase 4): it-tools and hr-portal, the first cutover wave

The two apps move here from wave-00 unchanged (same client IDs, certificates, identifiers, assignments). Plan, risk score and dates: [docs/wave-01-plan.md](../../docs/wave-01-plan.md).

| File | What it holds |
|---|---|
| `app-it-tools.tf` | `iac-saml-it-tools` (low risk), assigned to `iac-it`; claims through the msgraph `customClaimsPolicy` |
| `app-hr-portal.tf` | `iac-saml-hr-portal` (tier 1), assigned to all three staff groups; claims through the msgraph `customClaimsPolicy` (replaced the claims mapping policy); `groups` from the app registration (`group_membership_claims`, optional claim) |
| `ca-policies.tf` | `LAB-CA11 - Wave-01 SAML apps - Require MFA - Finance - Any location`, report-only (wave-00's `LAB-CA10` no longer lists these apps) |
| `data.tf`, `variables.tf`, `tenants/*.tfvars`, `backend.tf`, `providers.tf`, `versions.tf` | As wave-00 (no `use_shared_audience`); state `entra/waves/wave-01/terraform.tfstate` |

The move used one-time files: `imports.tf` here (import blocks with the wave-00 object IDs, per `tenant_key`) and `moves.tf` in wave-00 (`moved` + `removed` blocks). Both were deleted once both copies were applied; see PR #14 for their shape.

## Who runs it, and how

- From Lab Phase 3, only the pipeline applies here: `plan.yml` on every pull request (both copies), `apply.yml` after merge (nonprod, then prod after approval), `drift.yml` nightly (prod).
- Local plans are fine for checking; use the nonprod `TF_DATA_DIR` pattern in [../platform/README.md](../platform/README.md).

## How to add a wave

1. Copy `wave-00` to `wave-NN`. Keep `data.tf`, `variables.tf`, `providers.tf`, `versions.tf`; change the state key in `backend.tf` to `entra/waves/wave-NN/terraform.tfstate`.
2. Move or write the apps for this batch. An app lives in exactly one wave; moving an existing one never deletes and re-creates it. In the old wave, add a `removed` block with `lifecycle { destroy = false }`; in the new wave, an `import` block by object ID. A `removed` block cannot name one instance of a `for_each` resource, so first `moved` that instance to a plain name and remove that name, in the same change (tested 2026-10-26; [docs/wave-01-plan.md](../../docs/wave-01-plan.md) section 4).
3. **Create the state file once with your own login**, for both containers, before the first pull request. The planner can only read state, so it fails with `403 AuthorizationPermissionMismatch` on a state file that does not exist:
   ```bash
   for c in tfstate-prod tfstate-nonprod; do terraform -chdir=entra/waves/wave-NN init -reconfigure -backend-config=container_name=$c; done
   ```
4. Open a change ticket and a pull request. The pipeline picks up the new folder automatically (it plans every `entra/waves/*` that has a `tenants/<tenant_key>.tfvars`).

## Read next
- [docs/migration-runbook.md](../../docs/migration-runbook.md): the step-by-step runbook each wave follows.
- [docs/build-by-hand.md](../../docs/build-by-hand.md) parts 12 and 13: first build and sign-in tests.
