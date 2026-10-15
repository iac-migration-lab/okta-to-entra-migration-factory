# Claude Code Prompts for IP0 Run 1

One prompt per session, pasted as the first message of a fresh `claude` session in `~/Projects/okta-to-entra-migration`. Each session ends with a findings entry and a commit. Scope: docs/run-1-scope.md. Steps: docs/build-phases.md. Rules: CLAUDE.md (autonomy in the lab, permission register, hard rules).

## How to run a session

1. Terminal, in the repo:
   ```bash
   cd ~/Projects/okta-to-entra-migration && source lab-tools/env.sh && git pull && az account show --query user.name -o tsv && gh auth status 2>&1 | head -3
   ```
   Expect `la-migration-lab@outlook.com`. If not: `az login --allow-no-subscriptions --use-device-code`, sign in as that address in a private window.
2. `claude` in default permission mode. Not `--dangerously-skip-permissions`: the lab pre-approves grants, but you still want to see each shell command once.
3. Paste the session prompt. It will ask at most one question per turn; when it needs a console step or a browser sign-in, do it and paste what it asks for.
4. Secrets stay in `~/.okta-lab/` (chmod 600) and GitHub environment secrets. Never paste a key, token, or password into the session.
5. Sign in to the Okta Admin Console weekly so the Integrator org stays active.

## Session 0: adopt run 1 scope

```
Read CLAUDE.md, docs/run-1-scope.md, docs/claude-code-prompts.md, docs/build-phases.md, and the last three entries of docs/findings-log.md.

No cloud changes this session.

1. Add docs/run-1-scope.md to CLAUDE.md "Read first, every session" as the first bullet: it narrows run 1 to the three proof points and defers Lab Phases 5, 6, 7.
2. In docs/build-phases.md, mark Lab Phases 5, 6, 7 "Deferred (run 1), see docs/run-1-scope.md" in their headings, and note that Lab Phase 8 runs as Lab Phase 5 in run 1. Do not rewrite step text.
3. Findings entry "Run 1 scope adopted; second repo not used": the three proof points, the deferred items, why mlencioni/okta-to-entra-migration-factory is not used, the stray ~/okta-entra-migration folder, the multi-tenant hook, and the run 2 and run 3 revisit trigger from run-1-scope.md section 7.
4. git status must show only CLAUDE.md, docs/build-phases.md, docs/findings-log.md changed (plus the untracked .claude/ folder, which you add to .gitignore). Commit "Run 1 scope: Okta to Entra pipeline only" and push.
5. One question: rename the repo to okta-to-entra-migration-factory now, before Lab Phase 3 creates federated-credential subjects? If yes, run gh repo rename, update origin and every doc that names the repo, log it, commit, push.
```

## Session 1: seed Okta, create the reader identity (Lab Phase 1, steps 1 and 2)

```
Read CLAUDE.md, docs/run-1-scope.md, docs/okta-seed-spec.md, docs/permission-register.md, and the last findings entry. Header must say Run 1, Lab Phase 1.

1. Seeding. Tell me the one export line for OKTA_ORG_URL and OKTA_API_TOKEN_FILE (the token file is already in ~/.okta-lab/), then I run the seed script dry, paste you the output, you fix anything it flags, then I run it with --apply and paste the output. Anything the script could not create: give me the click path and the exact values from the spec; I do it and tell you. Record total seeding time.
2. Smoke test from the seed spec (I do the sign-ins); record results.
3. Create iac-okta-reader as an API Services app with private key JWT, the seven read scopes from CLAUDE.md's production target design, and the Read-only Administrator role. Use the SSWS token to create and grant where the API allows it; give me a click path for the rest (key generation stays in the console or on my machine; the private key goes to ~/.okta-lab/iac-okta-reader.pem and to 1Password, never to you). Add a register row at creation with the production verdict.
4. Verify read access with the new identity (one read call, no SSWS), paste me the counts per object type, and compare with the seed spec's expected counts.
5. Findings entry "Run 1, Lab Phase 1: Okta org seeded; reader identity created" with counts, seeding time, client ID, key ID. Confirm nothing under ~/.okta-lab/ or any token is staged. Commit and push.
```

## Session 2: import and normalize the Okta inventory (Lab Phase 1, steps 3 and 4)

```
Read CLAUDE.md, docs/run-1-scope.md, docs/terraform-provider-analysis-okta-entra-sailpoint.md section 2, docs/build-phases.md Lab Phase 1, and the last findings entry.

Local Terraform only in this session: init, validate, fmt, plan, import, -generate-config-out. Local state for now. The reader key is at ~/.okta-lab/iac-okta-reader.pem; read it into the provider through an environment variable, never into a file in the repo.

1. okta-inventory/versions.tf and providers.tf: okta/okta pinned ~> 7.0, org integrator-2631921, base URL okta.com, OAuth 2.0 service app auth with client_id, private_key_id, private_key, scopes; max_api_capacity = 50; default backoff. Verify argument names against the provider docs; in run 1, if unsure, try it and log the result.
2. One import block per seeded object (users incl. the deactivated one, groups, the six apps, zone, policies and rules, authorization server, scope, claim, policy and rule). Get IDs with read calls through the reader identity.
3. terraform init, then terraform plan -generate-config-out=generated.tf. Paste me the summary.
4. Normalize generated.tf into okta-inventory/ modules by object type. Time each app in minutes. Keep a list of every attribute the generator got wrong or that diffs on the next plan, including the Slack preconfigured-app noise the plan predicts. Goal: terraform plan shows zero changes; if a known provider bug blocks zero, record it and move on.
5. Findings entry "Run 1, Lab Phase 1: Okta inventory imported and normalized" with per-app minutes and the wrong-attribute list. git status must show no .tfstate, .tfvars, or key. Commit and push.
```

## Session 3: state backend, reader federation, snapshot workflow (Lab Phase 1, steps 5 to 7)

```
Read CLAUDE.md, docs/run-1-scope.md section 4 Lab Phase 1, docs/lab-naming.md, docs/permission-register.md, and the last findings entry.

This session creates Azure resources and the first Entra app registration. Pre-approved in the lab; register every grant as you make it.

1. Create rg-iac-lab, stiaclabtfstate (versioning and soft delete on), containers tfstate-nonprod and tfstate-prod; app registration iac-reader with a federated credential for repo:iac-migration-lab/identity-as-code-lab:ref:refs/heads/main; Storage Blob Data Contributor for iac-reader on the state container. Record IDs, region, and the state-key table in docs/lab-naming.md and docs/migration-runbook.md section 3. Register rows for the role assignment and the app registration.
2. Move okta-inventory to the azurerm backend with use_oidc, key okta-inventory/terraform.tfstate in tfstate-prod. terraform init -migrate-state with my Azure CLI login; plan must still be zero changes. Delete the local state file afterwards and confirm.
3. .github/workflows/snapshot.yml: nightly cron plus workflow_dispatch; permissions id-token: write, contents: write; azure/login by OIDC; Okta private key from secret OKTA_PRIVATE_KEY in GitHub environment okta-read; terraform plan -detailed-exitcode; counts only to docs/inventory-counts.md, committed back; user and assignment JSON to blob container okta-exports, never to Git. Pin action versions.
4. Tell me the secrets and variables to create in environment okta-read and where to click. I create them.
5. Trigger the workflow by hand; fix until green; paste me the run URL. Then I change one thing in the Okta Admin Console (tell me what); next run must exit 2 and show it.
6. Findings entry "Run 1, Lab Phase 1: snapshot green; drift detected" with both run URLs and what to check after the second nightly run. Update migration-runbook.md section 4 statuses. Commit and push.
```

## Session 4: P2 trial, break-glass, brownfield import (Lab Phase 2, steps 1 to 4)

```
Read CLAUDE.md, docs/run-1-scope.md section 4 Lab Phase 2, docs/build-phases.md Lab Phase 2, docs/terraform-provider-analysis-okta-entra-sailpoint.md section 3, docs/permission-register.md, and the last two findings entries. Lab Phase 1 exit (second green nightly run) must be logged; if not, stop and say so.

1. Set the header to Run 1, Lab Phase 2 and commit that alone. Give me the click path to activate the Entra ID P2 trial (la-migration-lab@outlook.com, private window). When I say active, log the start and end dates.
2. Break-glass bg-admin-01 and group bg-ca-exclusion with bg-admin-01 and la-migration-lab@outlook.com as members. Create by CLI where you can; click path for credential enrollment (passphrase plus FIDO2 or authenticator, no factor shared with the owner account). Register rows.
3. Brownfield objects by hand in the portal (click paths, I click): 3 CA policies (one report-only; all exclude bg-ca-exclusion), 1 named location, 1 authentication strength, 2 security groups, 1 gallery enterprise app. Names follow LAB-CA<NN> - <Apps> - <Control> - <Persona> - <Conditions>.
4. entra/legacy/: hashicorp/azuread pinned ~> 3.9; variables tenant_key and tenant_id only; azurerm backend key entra/legacy/terraform.tfstate in tfstate-prod; prevent_destroy on every resource; one import block per object. terraform init and plan with my Azure CLI login until zero changes. No apply needed in this step.
5. Findings entry "Run 1, Lab Phase 2: brownfield imported, plan clean" with the attribute mismatches you fixed. Update runbook section 1 statuses. Commit and push.
```

## Session 5: translate apps and the claims experiment (Lab Phase 2, steps 5 to 7)

```
Read CLAUDE.md, docs/run-1-scope.md section 4 Lab Phase 2, docs/okta-seed-spec.md sections 3 and 4, docs/terraform-provider-analysis-okta-entra-sailpoint.md sections 3.3 and 4, and the last findings entry.

No pipeline exists yet, so local terraform apply is allowed in this session for wave-00 and platform; log each apply. Prefer one apply per root.

1. From the normalized Okta modules, write entra/waves/wave-00/: the four SAML apps (iac-saml-it-tools via azuread_application_from_template with a gallery template if one fits, the other three as custom SAML), group assignment, SAML signing certificate, ACS https://sptest.iamshowcase.com/acs. The seed spec warns all four share audience IAMShowcase; find out what Entra does with duplicate identifier URIs and log the workaround. Add iac-oidc-portal as an app registration plus service principal with redirect https://oidcdebugger.com/debug and the department claim. Same tenant_key and tenant_id variables as entra/legacy.
2. Claims: iac-saml-hr-portal via azuread_claims_mapping_policy; iac-saml-it-tools via microsoft/msgraph pinned to an exact version writing a customClaimsPolicy (beta); iac-saml-custserv-desk claims in the portal only.
3. entra/platform/: the Okta zone as azuread_named_location, the Okta authentication policy as one report-only CA policy excluding bg-ca-exclusion.
4. Apply, then I test: SAML sign-in through Entra for at least one app, OIDC sign-in through oidcdebugger. Then the experiment: I edit each SAML app's claims in the portal; you run terraform plan after each and record what the provider sees, ignores, or would overwrite.
5. Findings entry "Run 1, Lab Phase 2: apps translated; claims experiment" with a three-row table (mechanism, what plan showed, what the portal showed) and screenshot names under docs/evidence/. Update runbook section 5 statuses. Commit and push.
```

## Session 6: pipeline (Lab Phase 3)

```
Read CLAUDE.md, docs/run-1-scope.md section 4 Lab Phase 3, docs/build-phases.md Lab Phase 3, docs/change-gate-design.md, .github/workflows/placeholder.md, docs/permission-register.md, and the last findings entry. Set the header to Run 1, Lab Phase 3 and commit that alone.

Admin consent is mine, from the break-glass account; everything else you do.

1. iac-planner (subject ...:pull_request) and iac-applier (...:environment:nonprod, ...:environment:prod) with federated credentials; add Directory.Read.All and Policy.Read.All to iac-reader. Graph permissions and storage RBAC exactly as build-phases Lab Phase 3 steps 2 and 3. Register rows for every permission and role. Give me the consent click path and wait for "consented".
2. Bring budget-iac-lab-monthly into code (say where and why).
3. Click path for GitHub environments nonprod (no rules) and prod (required reviewer iac-lab-reviewer; I create that account first), plus the variables each workflow needs (client IDs, tenant ID, subscription ID). No secrets needed for Entra.
4. policy/: Conftest rules on the plan JSON: every CA policy excludes bg-ca-exclusion; every new CA policy is report-only; nothing under entra/legacy is destroyed. One passing and one failing fixture, and a test command.
5. Change-gate reusable workflow per docs/change-gate-design.md with the GitHub Issues adapter, issues: read only.
6. plan.yml (PR: fmt, validate, plan per root with a tenant_key matrix, plan JSON artifact, conftest), apply.yml (merge: nonprod, then prod after environment approval, change gate first), drift.yml (nightly plan -detailed-exitcode on prod; exit 2 opens or updates one issue labeled drift). Pin action versions. Delete placeholder.md.
7. Exit tests, one PR each, I open and approve: (a) a CA policy missing the exclusion fails conftest; (b) a PR with no Change: line fails the gate; (c) a compliant PR with a scheduled change issue applies to nonprod on merge and to prod only after iac-lab-reviewer approves. Then I induce one drift in the portal; drift.yml opens exactly one issue.
8. Findings entry "Run 1, Lab Phase 3: pipeline proven" with the PR URLs and the drift issue URL. Update runbook sections 2, 3, 6. Commit and push.
```

## Session 7: cutover wave and rollback (Lab Phase 4)

```
Read CLAUDE.md, docs/run-1-scope.md section 4 Lab Phase 4, docs/build-phases.md Lab Phase 4, and the last findings entry. Set the header to Run 1, Lab Phase 4 and commit that alone.

From here, migrated objects change only through the pipeline.

1. docs/wave-01.md: two apps from wave-00 (one low risk, one tier 1), risk score from assignment count, validation windows 2 and 5 days, sign-off by iac-lab-reviewer PR approval.
2. iac-okta-cutover: okta.apps.manage only; check which admin role, if any, assignment removal needs and log it. Key to ~/.okta-lab/ and to GitHub environment okta-cutover, usable only by apply.yml on prod. Register row.
3. entra/waves/wave-01/ PR with Change: github:<issue>; I approve; the pipeline applies. I test both apps against the SP through Entra.
4. Second PR adds an okta-cutover step (prod only, okta-cutover environment) that removes the two apps' Okta group assignments by ID. Next snapshot must show exactly those changes.
5. Rollback drill: PR to re-add the assignments; I prove sign-in through Okta; PR to remove again. Time both.
6. Findings entry "Run 1, Lab Phase 4: wave 01 cut over; rollback drilled" with timings and run URLs. Deactivate iac-okta-cutover (click path or API). Update runbook sections 6, 7, 8. Commit and push.
```

## Session 8: retro and teardown (Lab Phase 5, was 8)

```
Read CLAUDE.md, docs/run-1-scope.md sections 6 and 7, docs/permission-register.md, docs/migration-runbook.md, and every findings entry from Run 1 Lab Phase 1 on. Set the header to Run 1, Lab Phase 5 and commit that alone.

1. docs/retro.md: for each of the ten definition-of-done lines, the evidence (entry date, URL); for each of the three proof points, what run 1 confirmed, contradicted, could not test; the numbers (per-app normalization minutes, per-app translation minutes, claims decision with reasons, pipeline build hours); and the list of run 1 shortcuts run 2 must remove (start from every Not OK row in the register).
2. git log -p scan for BEGIN PRIVATE, SSWS, client_secret, and the export JSON file names. Report the result.
3. Teardown: revoke the SSWS token iac-run1-seed and the iac-okta-reader and iac-okta-cutover keys; delete iac-reader, iac-planner, iac-applier; delete rg-iac-lab after confirming the retro is pushed (this removes state); cancel the P2 trial (click path); delete the budget; remove delete_repo from gh if present. Mark each register row's verdict.
4. Final findings entry "Run 1, Lab Phase 5: retro written; lab torn down". Set the header to Run 1 closed. Commit and push. Tell me what is still running or costing money, or say nothing is.
```
