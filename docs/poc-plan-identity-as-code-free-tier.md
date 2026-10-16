# Identity as Code Proof of Concept on Free Tiers

Personal lab to exercise the Okta-to-Entra migration method end to end before proposing it. Free-tier facts verified September 30, 2026. Nothing here touches the owner's production tenants, accounts, or any client environment.

## 1. What this POC can and cannot prove

Be honest with yourself about this up front, because it shapes what you carry back to the client plan.

**Can prove (real platforms, real APIs):**
- Okta read-only inventory via Terraform import + generate-config, nightly snapshots, PII split (counts in Git, JSON in Azure Storage).
- Entra ID brownfield import of hand-built Conditional Access (CA) policies and apps, and a clean plan afterward.
- Okta SAML app translated into an Entra enterprise app, with both claims mechanisms (claims mapping policy vs custom claims policy) tried on real apps.
- The pipeline: OpenID Connect (OIDC) federation from GitHub Actions to Entra with no secrets, three pipeline identities, environment gates, ITSM-agnostic change-ticket gate (docs/change-gate-design.md), OPA (Open Policy Agent)/Conftest rules, drift job that opens a GitHub issue.
- A two-app cutover wave with validation window, Okta assignment removal, and a rollback drill.
- The msgraph (Microsoft Graph) preview provider on one real gap object (authentication methods policy).
- Microsoft365DSC (Desired State Configuration) as a read-only snapshot/drift tool.

**Cannot prove (no free path exists):**
- SailPoint Identity Security Cloud (ISC) behavior. SailPoint staff state on their developer forum: "You must first be a customer or partner to receive a tenant of any kind." The POC substitutes a mock server built from SailPoint's published OpenAPI specs. That proves the SP-Config pipeline shape, not SailPoint's import behavior.
- Hybrid identity: Entra Connect, Password Hash Sync, Staged Rollout, domain federation cutover. Needs on-prem Active Directory (AD). Optional stretch phase if you stand up a Windows Server evaluation VM; otherwise out of scope.
- Scale. Ten Okta users and a handful of apps will not surface rate-limit or plan-time behavior. Note that explicitly when you report findings.

## 2. Free-tier bill of materials (verified)

| Platform | Free offering | Limits that matter | Clock |
|---|---|---|---|
| Okta | Integrator Free Plan | 10 active users, 5 Workflows, limited per-minute rate limits, no Org2Org, no editable email templates. Requires a unique business email per org. | Deactivates after 90 days with no sign-in |
| Entra ID | Free tenant + Entra ID P2 trial | CA, PIM (Privileged Identity Management), access packages, auth strengths all need P1/P2, so the trial is mandatory for the real work. Global Administrator on the tenant required to activate. | P2 trial is time-limited (Microsoft's page does not state duration; plan for 30 days) |
| Entra ID (alternative) | Microsoft 365 E5 developer sandbox | Includes Entra P2, 25 licenses, 90 days renewable. Eligibility is Visual Studio Pro/Enterprise subscribers, ISV/partner program members, or Premier/Unified support customers. Not open to individuals otherwise. | 90 days, renewable on activity |
| Azure | Azure free account | $200 credit for 30 days, always-free tiers after. Credit card required ($1 auth hold). Storage account for Terraform state costs pennies. | 30-day credit window |
| GitHub | Free plan | Environments with required reviewers and wait timers are only available on PUBLIC repositories on Free/Pro/Team. Private repos need Enterprise. | None |
| ITSM (IT Service Management) | GitHub Issues as the change-record stand-in (ServiceNow PDI had no instances available 2026-10-01) | Labels for state, body lines for the window; see docs/change-gate-design.md. | None |
| Terraform | Community Edition (CE) | Business Source License; fine for personal use. | None |
| Microsoft365DSC | Open source PowerShell | Read-only export only in this POC. | None |
| SailPoint ISC | None | Substitute: Stoplight Prism mock server fed by sailpoint-oss/api-specs OpenAPI, plus the SailPoint CLI pointed at the mock. | None |
| SAML test Service Provider (SP) | samltest.id or similar free SAML SP tester | Lets you prove an assertion from Okta, then from Entra, for the same app. | None |

**Two assumptions that do not hold, so design around them:**
1. GitHub environment gates on a private repo are not free. The POC repo is public, which is fine because state lives in Azure Storage, credentials are OIDC-federated, and tenant identifiers are not secrets. Never commit a PEM key, a client secret, or exported user JSON.
2. The Microsoft 365 developer sandbox is not open to individuals without a Visual Studio subscription. Use a fresh Entra tenant plus the P2 trial instead, and run the Entra phases inside the trial window.

## 3. Isolation rules (least-privilege gate applied to the lab)

- Dedicated throwaway identities for everything: a new mailbox or alias used only for this lab (Okta needs a unique business email per org; a Gmail plus-alias may be rejected, so use a domain you control or a free Outlook address).
- Never use the owner's production Microsoft 365 tenant, SharePoint, or GitHub organization. Create a new Entra tenant and a new GitHub organization (free) named for the lab.
- Okta inventory identity: OAuth 2.0 API service app with private key JWT (JSON Web Token), read scopes only (`okta.apps.read`, `okta.users.read`, `okta.groups.read`, `okta.policies.read`, `okta.authorizationServers.read`, `okta.idps.read`, `okta.schemas.read`), assigned the built-in Read-only Administrator role. The private key is a static credential, which is the one place federation is not available; store it as a GitHub environment secret, rotate it at the end of the POC, and record that as an accepted risk.
- Okta cutover identity: a second service app with `okta.apps.manage` only, used in Phase 4 to remove assignments, disabled between waves.
- Entra identities: three app registrations (`iac-reader`, `iac-planner`, `iac-applier`) with federated credentials bound to specific GitHub repo + environment subjects. No client secrets anywhere. Graph application permissions kept to what each phase needs (table in Phase 3).
- Azure Storage: versioning and soft delete on; `iac-applier` gets Storage Blob Data Contributor on the state container only, `iac-reader` gets Storage Blob Data Reader. Skip private endpoints in the lab (cost); note it as a difference from the client design.
- Change gate: the workflow's `GITHUB_TOKEN` with `issues: read` only. In the client design, a dedicated read-only ITSM integration identity.
- Break-glass: one cloud-only Global Administrator account with a long passphrase and FIDO2 or authenticator app, excluded from every CA policy by module and by Conftest rule, exactly as the client design requires.

## 4. Phases

Each phase ends with exit criteria and a findings entry. Keep one running `findings-log.md` in the repo: what the docs said, what actually happened, what changes in the client plan.

### Phase 0: Accounts and skeleton (one evening)

- Create lab email, GitHub org and public repo (`okta-to-entra-migration-factory`, created as `identity-as-code-lab`, renamed 2026-10-15), Okta Integrator Free Plan org, Entra tenant, Azure free account. (ServiceNow PDI dropped 2026-10-01; see findings log.)
- Do NOT activate the Entra P2 trial yet. Its clock should start at Phase 2.
- Install locally: Terraform CE (pinned, 1.11 or later for write-only arguments), Azure CLI, Okta CLI optional, SailPoint CLI, PowerShell 7 + Microsoft365DSC, Conftest, Node (for Prism).
- Repo layout: `okta-inventory/`, `entra/legacy/`, `entra/platform/`, `entra/waves/`, `sailpoint/`, `policy/`, `.github/workflows/`, `docs/`.
- Exit: every account reachable; `terraform -version`, `sail --version`, `conftest --version` recorded in the findings log.

### Phase 1: Okta source build-out and Step 1 inventory (two evenings)

- Seed the Okta org to look like a miniature enterprise org: 8 users across 3 groups (IT, CustServ, Finance), 3 custom SAML 2.0 apps pointed at the SAML test SP (one per group), 1 OIDC web app, 1 app with group-based assignment and attribute statements, 1 preconfigured OIN (Okta Integration Network) app so you hit the known `okta_app_saml` drift noise, a network zone, a password policy, a global session policy, an authentication policy (OIE only, confirms your org is Identity Engine), and a custom authorization server.
- Create the read-only service app and grant scopes. Write `providers.tf` with `max_api_capacity = 50` and default backoff.
- Write `import` blocks for every object, run `terraform plan -generate-config-out=generated.tf`, then normalize the output into modules. Record how long the normalization took per app: this is the number that feeds the effort estimate.
- Build the nightly snapshot GitHub Actions workflow (schedule + manual dispatch): `terraform plan -detailed-exitcode`, write aggregate counts to `docs/inventory-counts.md`, write the full user/assignment JSON to Azure Blob, never to Git.
- Introduce drift by hand in the Okta admin console; confirm the next snapshot reports it.
- Exit: snapshot green two nights running; drift detected once; findings log has the per-app normalization time and the list of attributes generate-config got wrong.

### Phase 2: Entra brownfield import and translation layer, Step 2 (three evenings, inside the P2 trial window)

- Activate the Entra ID P2 trial. Note the date; everything in Phases 2 to 4 happens before it expires.
- Simulate brownfield: by hand in the portal, create 3 CA policies (one in report-only), 1 named location, 1 authentication strength, 2 security groups, 1 enterprise app from the gallery. This simulates a tenant with substantial portal-managed CA.
- Import all of it into `entra/legacy/` with `prevent_destroy` on every resource. Exit criterion: `terraform plan` shows zero changes after import.
- Translate the three Okta SAML apps: one via `azuread_application_from_template` using the gallery template, two as custom SAML (non-gallery template ID). Re-point the SAML test SP at Entra and prove the assertion.
- Claims experiment, the most valuable thing in the POC: configure one app's claims with `azuread_claims_mapping_policy`, another with the msgraph provider writing a `customClaimsPolicy` (beta), and leave the third configured only in the portal. Then edit each in the portal and run `terraform plan`. Record exactly what the provider sees, what it silently ignores, and what the portal shows after each apply. This result goes straight into the client's translation-layer design.
- Translate the Okta network zone to a named location and the Okta authentication policy to a CA policy (report-only first, enforced by Conftest rule).
- Exit: three apps authenticating via Entra against the test SP; claims findings written up with screenshots; plan is clean.

### Phase 3: Repository and pipeline, Step 3 (two evenings)

- Create `iac-reader`, `iac-planner`, `iac-applier` app registrations with federated credentials. Subjects: `repo:<org>/okta-to-entra-migration-factory:pull_request` for planner, `repo:<org>/okta-to-entra-migration-factory:environment:nonprod` and `:environment:prod` for applier.
- Graph application permissions for the lab scope (CA + apps + groups): reader `Directory.Read.All`, `Policy.Read.All`; planner same as reader; applier `Application.ReadWrite.All`, `Group.ReadWrite.All`, `Policy.ReadWrite.ConditionalAccess`, `Application.Read.All` (the CA 403 fix). Grant admin consent once, from the break-glass account.
- Azure Storage backend: one storage account, containers `tfstate-nonprod` and `tfstate-prod`, separate keys per layer (`legacy`, `platform`, `waves`). RBAC per section 3.
- GitHub environments `nonprod` (no gate) and `prod` (required reviewer = a second GitHub account you control, so requester-is-not-author is enforced for real).
- Change gate: a workflow step that reads `Change: <system>:<id>` from the PR body, calls that system's adapter (lab: GitHub Issues), and fails unless the normalized state is scheduled or implement and the planned window covers now. Design: docs/change-gate-design.md.
- Policy as code: Conftest rules on the plan JSON: every CA policy excludes the break-glass group; every new CA policy starts `enabledForReportingButNotEnforced`; no resource in `legacy/` may be destroyed.
- Drift job: nightly `plan -detailed-exitcode` on prod; exit code 2 opens or updates a GitHub issue, nothing else.
- Exit: a PR that violates a rule fails; a PR without a change ticket fails; a compliant PR applies to nonprod on merge and to prod after reviewer approval; drift issue opened once.

### Phase 4: Cutover wave and Okta decommission, Step 4 (two evenings)

- Wave plan for two apps (one low risk, one "tier 1"). Risk score from assignment count; validation windows 2 days and 5 days instead of 7 and 30.
- Sign-off recorded as PR approvals from the second GitHub account.
- Move the apps: Entra side applied in a wave state key; users test against the SAML SP; after the window, the Okta cutover identity removes the Okta assignments (not the app). Confirm the Okta nightly snapshot shows the assignment change and nothing else.
- Rollback drill: re-create the Okta assignment via the cutover identity, confirm the user can authenticate through Okta again, then re-remove.
- Exit: both apps on Entra; Okta assignments removed; rollback drill timed and logged.

### Phase 5: SailPoint stand-in (one evening, honest about limits)

- Clone `sailpoint-oss/api-specs`; run Stoplight Prism as a mock server on the ISC v2025 spec; point the SailPoint CLI at it.
- Author a SCIM 2.0 source definition, schema, and provisioning policy as SP-Config JSON by hand from the spec, matching one of the migrated apps.
- Build the `sailpoint/` pipeline: export (from mock) to JSON, diff against Git, import on merge. Secrets stripped on export, injected at import from a GitHub secret.
- Exit: pipeline runs green against the mock. Findings log states plainly that this validates mechanics only, and lists what can only be learned on a real tenant (object reference resolution between tenants, silent skip behavior, connector credential re-entry).

### Phase 6: Gap layer with the msgraph preview provider (one evening)

- In its own state key, manage the authentication methods policy (`policies/authenticationMethodsPolicy`) with `msgraph_update_resource`: enable Microsoft Authenticator and Temporary Access Pass, disable SMS. This mirrors the "MFA parity then hardening" decision.
- Record: did the body round-trip cleanly, did the plan show spurious diffs, what happened on provider version bump.
- Optional if you own a spare domain: verify it in the Entra tenant and exercise `internalDomainFederation` read-only. Do not federate it to anything.
- Exit: one gap object managed; findings on drift behavior recorded.

### Phase 7: Microsoft365DSC read-only snapshot (one evening)

- `Export-M365DSCConfiguration` for Entra components only, scheduled from the same workflow, output committed as a snapshot. Diff two nights.
- Exit: a DSC snapshot diff that agrees with the Terraform drift job.

### Phase 8: Retrospective and teardown (one evening)

- Write `docs/retro.md`: for each of the Step 1 to 4 design records, what the POC confirmed, what it contradicted, what it could not test.
- Pull the estimate-relevant numbers: per-app normalization time, per-app translation time, claims mechanism decision, pipeline build hours.
- Teardown: revoke the Okta private key, delete the Entra app registrations and the storage account, cancel the P2 trial. Keep the repo (public, no secrets) as a portfolio artifact.

## 5. Calendar

- Weeks 1 to 2: Phase 0 and 1. Okta org and Azure account are created; P2 not yet activated.
- Day 1 of Phase 2 (start of week 3): activate P2 trial. Phases 2, 3, 4 and 6 must finish within the trial window. Budget three weeks.
- Weeks 6 to 7: Phases 5, 7, 8.
- Keep-alive: sign in to Okta at least weekly so it is not deactivated.

Total: roughly 14 evenings over about seven weeks. If the P2 trial turns out shorter than 30 days, compress Phases 2 to 4 and move Phase 6 to the P2 tenant's free period (the authentication methods policy does not need P2).

## 6. Out-of-pocket cost

- $0 expected. Possible: a test domain ($10 to 15) for Phase 6 optional work; Azure storage beyond the credit window is cents per month.
- Credit card is required for the Azure account; spending protection keeps it at $0 unless you upgrade.

## 7. What to carry back into the client plan

- Per-app HCL (HashiCorp Configuration Language) normalization time from Phase 1, scaled with a stated caveat about sample size.
- The claims mechanism decision from Phase 2 (claims mapping policy vs custom claims policy vs portal), with evidence of what the provider sees and what it hides.
- The Conftest rule set from Phase 3, reusable as-is.
- The change-gate workflow from Phase 3, reusable with an adapter for the client's ITSM.
- The honest statement that SailPoint behavior remains unvalidated until the client grants a non-prod ISC tenant, and the list of specific questions to answer there.
- Any provider bug or version churn hit along the way, dated.

## Sources

- Okta Integrator Free Plan org defaults: https://developer.okta.com/docs/reference/org-defaults/
- Microsoft 365 Developer Program FAQ (eligibility): https://learn.microsoft.com/en-us/office/developer-program/microsoft-365-developer-program-faq
- Entra ID P1/P2 trial sign-up: https://learn.microsoft.com/en-us/entra/fundamentals/get-started-premium
- Azure free account terms: https://azure.microsoft.com/en-us/pricing/purchase-options/azure-account
- GitHub deployments and environments (plan availability): https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments
- SailPoint developer community on demo tenants: https://developer.sailpoint.com/discuss/t/how-can-we-get-demo-tenant-for-practice/56167
- SailPoint API specifications: https://github.com/sailpoint-oss/api-specs
- Companion: Terraform Provider Analysis (this project), September 30, 2026.