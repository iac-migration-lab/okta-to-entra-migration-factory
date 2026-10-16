# IP0 Run 1 Scope: Okta to Entra Pipeline Only

Decided 2026-10-05, written into the repo 2026-10-07 after the lab was reframed as Claude Identity as Code Implementation Phase 0 (IP0). This narrows what run 1 has to prove. It does not change CLAUDE.md's rules; the autonomy rules and the permission register stand. Session prompts for Claude Code are in docs/claude-code-prompts.md.

## 1. What run 1 has to prove

Three things, nothing else:

1. **Okta discovery as code, read-only.** The seeded Okta org is inventoried by Terraform (import + generate-config), normalized into HCL (HashiCorp Configuration Language), and snapshotted nightly from GitHub Actions, with drift reported and PII (personally identifiable information) kept out of Git.
2. **Entra write path as code.** Hand-built Entra objects come under Terraform with zero diff (brownfield import), and the Okta SAML (Security Assertion Markup Language) and OIDC (OpenID Connect) apps are translated into Entra apps that sign users in.
3. **CI/CD (continuous integration and delivery) between the two.** A pull request plans, passes policy, passes a change gate, applies to nonprod on merge and to prod behind a reviewer, with no stored Entra secrets (federated credentials), and a drift job that opens an issue. One cutover wave and one rollback run through that pipeline.

## 2. Deferred (not in run 1)

| Deferred | Was | Why | What survives |
|---|---|---|---|
| SailPoint stand-in (Prism mock, SP-Config pipeline) | Lab Phase 5 | Not between Okta and Entra | `sailpoint/README.md`; folder untouched |
| msgraph preview provider gap layer | Lab Phase 6 | Not needed for the three points above | Claims experiment in Lab Phase 2 still tries msgraph on one app, because claims are on the critical path |
| Microsoft365DSC snapshot | Lab Phase 7 | Terraform drift job proves the point | Module stays installed |
| Multi-tenant Entra model (parent/child tenants) | Oct 5 design draft | Client design still moving; one lab tenant exists | One hook only, section 5 |

Nothing is deleted. Deferred items are marked in docs/build-phases.md and can be picked up in run 2 or 3.

## 3. Facts run 1 works with

| Thing | Value |
|---|---|
| Lab email (Azure, Entra, budget alerts) | `la-migration-lab@outlook.com` |
| Okta org | `integrator-2631921` (`https://integrator-2631921.okta.com`, Admin Console `https://integrator-2631921-admin.okta.com`), admin `mark@lencioni.io` |
| Okta seed | docs/okta-seed-spec.md, `okta-inventory/seed/seed-okta-org.sh`; run 1 uses the SSWS token `iac-run1-seed` (permission register #4, revoke at end of run 1) |
| SAML test SP (service provider) | `https://sptest.iamshowcase.com` (ACS `https://sptest.iamshowcase.com/acs`, audience `IAMShowcase`) |
| OIDC tester | `https://oidcdebugger.com/debug` (UNVERIFIED: still running) |
| Entra lab tenant | `IaC Migration Lab`, `lamigrationlaboutlook.onmicrosoft.com`, tenant ID `bed5d4c3-98f0-4c73-9e4c-0b6cd3b9a0a4`, P2 trial active 2026-10-16 to 2026-11-16 |
| Azure subscription | `Azure subscription 1`, `6ea51c80-90de-4914-bbc6-2af9b54bba9f`, $10 monthly budget alert |
| GitHub | org `iac-migration-lab`, repo `okta-to-entra-migration-factory` (renamed from `identity-as-code-lab` 2026-10-15), public, `main` |
| Local clone | `~/Projects/okta-to-entra-migration`, tools in `lab-tools/` (git-ignored), local secrets in `~/.okta-lab/` |
| Break-glass (Lab Phase 2) | `bg-admin-01@lamigrationlaboutlook.onmicrosoft.com`, group `bg-ca-exclusion` |
| Entra pipeline identities | `iac-reader`, `iac-planner`, `iac-applier` |
| Okta service apps | `iac-okta-reader` (read), `iac-okta-cutover` (apps.manage) |

Passwords and keys live in 1Password and `~/.okta-lab/` only.

### Repo decision (2026-10-05)
- `mlencioni/okta-to-entra-migration-factory` (private, personal account, created 2026-10-05) is **not used**. On the Free plan a private repo has no required reviewers and no environment secrets, which removes the `prod` gate and the per-environment federated-credential subjects run 1 exists to prove (findings entry 2026-10-01 "Private GitHub repo created"). Owner deletes it.
- Run 1 stays in the lab org repo, renamed in place on 2026-10-15 from `identity-as-code-lab` to `iac-migration-lab/okta-to-entra-migration-factory` (`gh repo rename`); history, settings, and public visibility carried over. Done before any federated-credential subject, which contains the repo name, existed.
- Stray local folder `~/okta-entra-migration` (duplicate Lab Phase 0 run on 2026-10-05, two commits, no remote): delete.

## 4. Lab phases in run 1

Each lab phase ends with a findings entry (`Run 1, Lab Phase N`) and an update to the two header lines of docs/findings-log.md. Steps are in docs/build-phases.md; this section only says what changes for run 1.

### Lab Phase 1: Okta read-only discovery
- Seed with the script (dry run, then `--apply`), then the smoke test from the seed spec.
- `iac-okta-reader` per the production target design in CLAUDE.md; register row at creation. Private key to `~/.okta-lab/` and to a GitHub environment secret.
- Import, generate-config, normalize; time each app.
- **Pulled forward from Lab Phase 3,** because the snapshot workflow needs state: resource group `rg-iac-lab`, storage account `stiaclabtfstate02` (`stiaclabtfstate` and `-01` were taken; versioning, soft delete), containers `tfstate-nonprod` and `tfstate-prod`; app registration `iac-reader` with a federated credential for `repo:iac-migration-lab@336396784/okta-to-entra-migration-factory@1399352055:ref:refs/heads/main` and Storage Blob Data Contributor on the state container (it writes the `okta-inventory` state; "reader" refers to Okta). Register rows for both.
- `snapshot.yml`, then one induced drift.
- Exit: snapshot green two nights; drift caught once; per-app normalization minutes and the wrong-attribute list logged.

### Lab Phase 2: Entra brownfield import and translation (P2 trial starts)
- Activate P2 when the first CA (Conditional Access) object is needed; log the date and the end date.
- Break-glass account and `bg-ca-exclusion`; also put `la-migration-lab@outlook.com` in the exclusion group (state storage lives in this tenant).
- Brownfield by hand per build-phases; CA names follow `LAB-CA<NN> - <Apps> - <Control> - <Persona> - <Conditions>`.
- Import into `entra/legacy/` with `prevent_destroy`; plan must be clean.
- Translate the four SAML apps and the OIDC app into `entra/waves/wave-00/`. Expect the shared audience `IAMShowcase` to collide on identifier URIs in Entra (seed spec warning); log what happens and the workaround.
- Claims experiment: mapping policy vs msgraph custom claims policy vs portal only.
- Local apply is allowed here (no pipeline yet); log each one.
- Exit: SAML and OIDC sign-in through Entra proven; claims findings with screenshots under `docs/evidence/`; plan clean.

### Lab Phase 3: Pipeline
- `iac-planner`, `iac-applier` with federated credentials; extend `iac-reader` with Graph read for the Entra drift job. Register rows for every Graph permission and RBAC (role-based access control) role.
- GitHub environments `nonprod` (open) and `prod` (reviewer `iac-lab-reviewer`).
- Change gate per docs/change-gate-design.md; Conftest rules; `plan.yml`, `apply.yml`, `drift.yml`.
- From here on, migrated objects change only through the pipeline.
- Exit: the four exit tests in build-phases pass; one drift issue.

### Lab Phase 4: Cutover wave and rollback
- Two apps from wave-00 moved in `entra/waves/wave-01/` through the pipeline; `iac-okta-cutover` removes the Okta assignments; rollback drill timed.
- Exit per build-phases.

### Lab Phase 5 (was 8): Retro and teardown
- `docs/retro.md` against section 6 below; docs/migration-runbook.md statuses updated to Run 1 where they worked.
- Teardown per build-phases, plus: revoke SSWS token `iac-run1-seed`; mark every register row's production verdict.

## 5. Multi-tenant hook

Every Entra root module (`entra/legacy`, `entra/platform`, `entra/waves/*`) takes two variables, `tenant_key` (short label; `lab` in run 1) and `tenant_id`, and reads nothing else about the tenant. State keys and workflow matrix entries are built from `tenant_key`. CA display names follow `<TENANT>-CA<NN> - <Apps> - <Control> - <Persona> - <Conditions>`. When the client's parent/child tenants are known, a new tenant is a map entry plus a federated credential, not a rewrite.

## 6. Definition of done for run 1

Each line needs a findings entry with evidence:

1. Okta inventory `terraform plan` is clean against the seeded org.
2. Nightly snapshot ran green two nights in a row from GitHub Actions, Okta key from an environment secret, state in Azure Storage.
3. A hand-made Okta change was reported by the next snapshot.
4. `entra/legacy` plan is clean after brownfield import.
5. SAML sign-in and OIDC sign-in through Entra proven, each app's claims mechanism recorded.
6. A PR that breaks a Conftest rule fails; a PR with no change issue fails; a compliant PR applies to nonprod on merge and to prod only after `iac-lab-reviewer` approves.
7. The drift job opened exactly one issue for one induced Entra drift.
8. One wave moved two apps; the rollback drill was timed.
9. No secret, key, token, or user export is anywhere in Git history.
10. docs/permission-register.md has a production verdict on every row; docs/migration-runbook.md has a status on every step.

## 7. Accepted risks and the revisit trigger

- **IP0 autonomy (2026-10-07):** permissions and lab changes are pre-approved; grants may be broad. Recorded in CLAUDE.md and the register. **Trigger:** run 2 replaces every "Not OK" row with the production-shaped grant; run 3 must be production-shaped end to end, or the runbook says why not.
- Okta admin is `mark@lencioni.io`; never connect the org to `lencioni.io`.
- SSWS token `iac-run1-seed` exists until end of run 1 (register #4).
- Lab Entra tenant and the Azure state storage share one tenant; break-glass and owner exclusion plus the Conftest rule cover lockout.
- Okta private key is a static credential in a GitHub environment secret; rotate at teardown.
- Pay-As-You-Go subscription with no spending cap; $10 budget alerts only.
- GitHub Issues as the change record proves mechanics, not segregation of duties.
