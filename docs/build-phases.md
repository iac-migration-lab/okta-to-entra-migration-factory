# Build Phases

Step-by-step run book for each phase of the lab. Phase 0 records what was actually done. Phases 1 to 8 are the plan (docs/poc-plan-identity-as-code-free-tier.md), adjusted for Phase 0 findings. Facts and names come from docs/lab-naming.md; outcomes go in docs/findings-log.md.

Conventions for every phase:
- Start each session with `source ~/Projects/okta-to-entra-migration/lab-tools/env.sh`.
- Do Microsoft sign-ins in a private browser window as `la-migration-lab@outlook.com`, never as `mark@lencioni.io` (that domain belongs to the company Microsoft 365 tenant).
- No local `terraform apply`. Local use is `init`, `validate`, `fmt`, `plan`, `import`, `-generate-config-out`.
- Before any grant (scope, role, Graph permission, RBAC (role-based access control), secret), state the least-privilege block from CLAUDE.md.
- Before every commit: `terraform fmt -recursive && terraform validate` (once Terraform files exist).
- End each phase with a findings entry and update `Current phase:` at the top of the findings log.

---

## Phase 0: Accounts and skeleton (done 2026-10-01)

Goal: every account reachable, tools installed and pinned, repo skeleton in place.

### Steps as run
1. **Repo skeleton.** Created the local repo with CLAUDE.md, plan, provider analysis, findings log, lab naming, and `.gitignore` (keys, state, tfvars, user exports, `lab-tools/`).
2. **Tools.** Ran the install block in docs/tool-install.md. Everything pinned and checksum-verified into `lab-tools/` (git-ignored), opt-in per terminal through `lab-tools/env.sh`.
   - Fixes found on the way: SailPoint CLI binary sits at `sail_Darwin_arm64/bin/sail` in the tarball; PowerShell is now a Homebrew formula, not a cask.
   - Final versions: Terraform 1.16.4, Azure CLI 2.90.0 (pinned with `brew pin`), sail 2.6.0, Conftest 0.71.0, PowerShell 7.6.6, Microsoft365DSC 1.26.909.1, Node 24.21.0, Prism 5.16.0.
   - Check: the version check block in docs/tool-install.md.
3. **GitHub.** Owner created the free org `iac-migration-lab` in the browser. Repo `identity-as-code-lab` created, commit email set to `mark@lencioni.io`, history rewritten to remove the personal email, repo deleted and recreated (a force-push leaves old commits fetchable by SHA (commit ID)), then made public. Public is required on the free plan for environment reviewers and environment secrets.
4. **Lab email.** `la-migration-lab@outlook.com`. An `@lencioni.io` alias was ruled out because that domain is in the company tenant.
5. **Okta.** Integrator Free Plan org `integrator-2631921` (Admin Console `https://integrator-2631921-admin.okta.com`). Okta rejected the Outlook address; the owner signed up with `mark@lencioni.io`. This org must never be connected to the lencioni.io tenant.
6. **Azure.** Free account signed up as the Outlook address in a private window. It turned out to be Pay-As-You-Go with no spending limit, so a $10 monthly budget alert `budget-iac-lab-monthly` was added.
7. **Entra.** Creating a separate workforce tenant was not offered (only Governed Workforce and External). The Azure sign-up's Default Directory became the lab tenant: renamed `IaC Migration Lab`, domain `lamigrationlaboutlook.onmicrosoft.com`, tenant ID `bed5d4c3-98f0-4c73-9e4c-0b6cd3b9a0a4`. P2 trial not activated.
8. **ITSM (IT Service Management).** ServiceNow developer instances were unavailable. Change gate redesigned to work with any ITSM, with GitHub Issues as the lab stand-in (docs/change-gate-design.md).
9. **Folders.** `okta-inventory/`, `entra/legacy/`, `entra/platform/`, `entra/waves/`, `sailpoint/`, `policy/`, each with a README.
10. **Exit check.** Read-only checks on GitHub, Azure, Entra, the budget, Okta's discovery URL, and the three tool versions. All passed.

### Exit (met)
Every account reachable; `terraform -version`, `sail --version`, `conftest --version` recorded.

---

## Phase 1: Okta source build-out and inventory (two evenings)

Goal: a realistic small Okta org, a read-only Terraform inventory of it, and a nightly snapshot that catches drift.

### Steps
1. **Seed the Okta org** (this is the "source" being migrated). Run 1: `okta-inventory/seed/seed-okta-org.sh`, spec in docs/okta-seed-spec.md:
   - 8 users. The Integrator Free Plan allows 10 active users and the admin counts as one, so stay at 8.
   - 3 groups: `IT`, `CustServ`, `Finance`.
   - 3 custom SAML 2.0 apps, one per group, pointed at a free SAML test SP (service provider). UNVERIFIED: samltest.id is still running; pick a working free SAML tester before starting.
   - 1 OIDC (OpenID Connect) web app.
   - 1 app with group-based assignment and attribute statements.
   - 1 preconfigured OIN (Okta Integration Network) app, to reproduce the known `okta_app_saml` drift noise.
   - 1 network zone, 1 password policy, 1 global session policy, 1 authentication policy, 1 custom authorization server.
   - Before seeding, confirm the org is Identity Engine: `curl -s https://<org>.okta.com/.well-known/okta-organization` returns `"pipeline": "idx"`. The method is OIE only (docs/okta-identity-engine-decision.md); stop if it returns Classic.
   - Record the object counts in the findings log.
2. **Create the read-only service app `iac-okta-reader`.** API Services app, private key JWT (JSON Web Token), scopes `okta.apps.read`, `okta.users.read`, `okta.groups.read`, `okta.policies.read`, `okta.authorizationServers.read`, `okta.idps.read`, `okta.schemas.read`, role Read-only Administrator. State the least-privilege block first. The private key never touches the repo; it goes to a GitHub environment secret.
3. **Provider configuration.** `okta-inventory/providers.tf`: provider `okta/okta` pinned `~> 7.0`, org `integrator-2631921`, base URL `okta.com`, auth with `client_id`, `private_key_id`, `private_key`, `scopes`; `max_api_capacity = 50`; default backoff.
4. **Import.** Use the OIE resources: `okta_policy_signon` is the global session policy, `okta_app_signon_policy` the authentication policy; run 2 adds `okta_authenticator` and `okta_policy_mfa` with `is_oie = true`. Never `okta_factor`. One `import` block per object, then `terraform plan -generate-config-out=generated.tf` (experimental; output needs cleanup).
5. **Normalize** `generated.tf` into modules. Time each app; that per-app time is the main number for the client estimate. List every attribute the generator got wrong.
6. **Snapshot workflow** `.github/workflows/snapshot.yml`: schedule plus manual run; `terraform plan -detailed-exitcode`; aggregate counts to `docs/inventory-counts.md` on branch `inventory-counts` (main is protected); full user and assignment JSON to Azure Blob only.
7. **Drift test.** Change something by hand in the Admin Console; confirm the next snapshot reports it.

### Open question to settle before step 6
The plan creates the Azure storage account and the `iac-reader` federated identity in Phase 3, but the Phase 1 snapshot needs Terraform state and Blob storage now. Decide whether to pull the storage account and `iac-reader` forward into Phase 1.

### Exit
Snapshot green two nights running; drift detected once; findings log has per-app normalization time and the list of wrong attributes.

---

## Phase 2: Entra brownfield import and translation (three evenings, inside the P2 trial)

Goal: a hand-built "legacy" Entra estate under Terraform with zero diff, and the three SAML apps working through Entra.

### Steps
1. **Activate the Entra ID P2 trial** in the lab tenant only. Write the date in the findings log; Phases 2, 3, 4 and 6 must finish before it ends. Set `Current phase: 2` first (CLAUDE.md gate).
2. **Simulate brownfield by hand in the portal:** 3 CA (Conditional Access) policies (one report-only), 1 named location, 1 authentication strength, 2 security groups, 1 gallery enterprise app. Every CA policy excludes the break-glass group `bg-ca-exclusion` and the owner account.
3. **Break-glass account** `bg-admin-01@lamigrationlaboutlook.onmicrosoft.com`: cloud-only Global Administrator, long passphrase plus FIDO2 or authenticator, member of `bg-ca-exclusion`.
4. **Import** everything into `entra/legacy/` with `prevent_destroy` on every resource. Exit for this step: `terraform plan` shows zero changes.
5. **Translate the three Okta SAML apps:** one with `azuread_application_from_template` (gallery template), two as custom SAML. Re-point the SAML test SP at Entra and prove the sign-in.
6. **Claims experiment:** app A via `azuread_claims_mapping_policy`, app B via the msgraph provider (`customClaimsPolicy`, beta), app C in the portal only. Edit each in the portal, run `terraform plan`, record what each method sees, ignores, and overwrites.
7. **Translate** the Okta network zone to a named location and the Okta authentication policy to a CA policy, in report-only first.

### Exit
Three apps signing in through Entra; claims findings written up with screenshots; plan clean.

---

## Phase 3: Repository and pipeline (two evenings)

Goal: pull request to plan to policy check to change gate to apply, with no stored Entra secrets.

### Steps
1. **App registrations** `iac-reader`, `iac-planner`, `iac-applier` with federated credentials. Subjects: `repo:iac-migration-lab@336396784/okta-to-entra-migration-factory@1399352055:pull_request` (planner), `...:environment:nonprod` and `...:environment:prod` (applier). No client secrets. The repo uses GitHub's immutable subject format (org and repo IDs after `@`); check with `gh api repos/<repo>/actions/oidc/customization/sub` before creating any credential (findings 2026-10-16).
2. **Graph application permissions** (least-privilege block first; admin consent only from the break-glass account): reader and planner `Directory.Read.All`, `Policy.Read.All`; applier `Application.ReadWrite.All`, `Group.ReadWrite.All`, `Policy.ReadWrite.ConditionalAccess`, `Application.Read.All`.
3. **State backend:** storage account `stiaclabtfstate` in `rg-iac-lab`, containers `tfstate-nonprod` and `tfstate-prod`, one key per layer (`legacy`, `platform`, `waves`). Versioning and soft delete on. `iac-applier` gets Storage Blob Data Contributor on the state container only; `iac-reader` gets Storage Blob Data Reader. Import the hand-made budget alert here or recreate it in code.
4. **GitHub environments:** `nonprod` (no gate) and `prod` (required reviewer: second account `iac-lab-reviewer`, so requester and approver differ).
5. **Change gate** per docs/change-gate-design.md: PR body line `Change: github:<issue>`; GitHub Issues adapter with `issues: read`; fail unless state is scheduled or implement and now is inside the window.
6. **Conftest rules** in `policy/`: every CA policy excludes the break-glass group; every new CA policy starts report-only; nothing in `entra/legacy/` is destroyed. Run `conftest test --policy policy/ <plan.json>` in the plan workflow.
7. **Workflows:** `plan.yml` (on PR), `apply.yml` (on merge: nonprod, then prod after approval), `drift.yml` (nightly; exit code 2 opens or updates an issue), `change-gate` step.

### Exit
A rule-breaking PR fails; a PR without a change fails; a compliant PR applies to nonprod on merge and to prod after approval; one drift issue opened.

---

## Phase 4: Cutover wave and Okta decommission (two evenings)

Goal: move two apps from Okta to Entra through the pipeline, then prove rollback.

### Steps
1. **Wave plan** for two apps (one low risk, one "tier 1"). Risk score from assignment count; validation windows of 2 and 5 days.
2. **Okta cutover identity** `iac-okta-cutover`: `okta.apps.manage` only, enabled for the wave, deactivated after. Least-privilege block first.
3. **Apply** the Entra side in a wave state key under `entra/waves/`, through a PR with a change issue and reviewer approval.
4. **Users test** against the SAML test SP.
5. **After the window,** the cutover identity removes the Okta assignments (not the apps). Confirm the Okta snapshot shows that change and nothing else.
6. **Rollback drill:** re-create the Okta assignment, confirm sign-in through Okta, remove it again. Time it.

### Exit
Both apps on Entra; Okta assignments removed; rollback drill timed and logged.

---

## Phase 5: SailPoint stand-in (one evening). Deferred (run 1), see docs/run-1-scope.md

Goal: prove the SP-Config pipeline shape against a mock, and say plainly what it does not prove.

### Steps
1. Clone `sailpoint-oss/api-specs`; run Prism (`prism mock <spec>`) on the ISC (Identity Security Cloud) v2025 spec.
2. Point the SailPoint CLI at the mock.
3. Write a SCIM 2.0 source, schema, and provisioning policy as SP-Config JSON by hand, matching one migrated app.
4. Build the `sailpoint/` pipeline: export from mock, diff against Git, import on merge. Secrets stripped on export, injected at import from a GitHub secret.

### Exit
Pipeline green against the mock. Findings log lists what only a real tenant can show: references between tenants, silent skips, connector credential re-entry.

---

## Phase 6: Gap layer with the msgraph provider (one evening). Deferred (run 1), see docs/run-1-scope.md

Goal: manage one object the azuread provider cannot, and record how it behaves.

### Steps
1. In its own state key, manage the authentication methods policy with `msgraph_update_resource`: enable Microsoft Authenticator and Temporary Access Pass, disable SMS. Pin msgraph to an exact version.
2. Record whether the body round-trips cleanly, whether plan shows spurious diffs, and what changes on a provider version bump.
3. Optional, only with a spare domain: verify it in the lab tenant and read `internalDomainFederation`. Do not federate it.

### Exit
One gap object managed; drift behavior recorded.

---

## Phase 7: Microsoft365DSC read-only snapshot (one evening). Deferred (run 1), see docs/run-1-scope.md

Goal: a second, independent view of drift.

### Steps
1. Run `Export-M365DSCConfiguration` for Entra components only, scheduled from a workflow; commit the output as a snapshot.
2. Diff two nights. If it fails on macOS or Linux, use a Windows GitHub Actions runner (macOS support is UNVERIFIED).

### Exit
A DSC (Desired State Configuration) snapshot diff that agrees with the Terraform drift job.

---

## Phase 8: Retrospective and teardown (one evening)

Run 1: this lab phase runs as Lab Phase 5 (docs/run-1-scope.md section 4).

Goal: carry the evidence into the client plan and leave nothing running.

### Steps
1. Write `docs/retro.md`: for each Step 1 to 4 design record, what the lab confirmed, contradicted, or could not test.
2. Pull the estimate numbers: per-app normalization time, per-app translation time, claims mechanism decision, pipeline build hours.
3. Teardown: revoke the Okta private key; delete the Entra app registrations and the storage account; cancel the P2 trial; delete the budget; remove `delete_repo` from the `gh` login if still present.
4. Keep the repo public as a portfolio artifact.

### Exit
Retro written; no billable resources left; findings log closed.
