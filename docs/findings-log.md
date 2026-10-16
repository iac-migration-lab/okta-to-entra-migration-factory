Current run: 1 (Implementation Phase 0)
Current lab phase: 2 (Lab Phase 1 exit pending: two green nightly snapshots)

# Findings Log

Append only. Newest entry at the bottom. Never rewrite an earlier entry; correct it with a new one.

## Entry template

```
## YYYY-MM-DD, Run N, Lab Phase N, short title
- What the docs said:
- What actually happened:
- Time taken:
- Evidence:
- Change to the client plan, if any:
- Accepted risks added, if any:
```

---

## 2026-10-01, Phase 0, Phase 0 started
- What the docs said: Phase 0 installs Terraform CE (Community Edition) 1.11+, Azure CLI (command-line interface), SailPoint CLI, Conftest, PowerShell 7 + Microsoft365DSC (Desired State Configuration), and Node; exit requires `terraform -version`, `sail --version`, `conftest --version` recorded here.
- What actually happened: Tool versions detected on this machine (macOS 26.6.2, arm64, Homebrew 7.0.6) before any install:
  - terraform: not installed
  - az: not installed
  - sail: not installed
  - conftest: not installed
  - pwsh: 7.6.6 (Homebrew cask)
  - node: 26.8.1 (Homebrew; "Current" line, not LTS (Long-Term Support). Prism 5.16.0 needs Node >= 24.18.0; lab will use Node 24.21.0 LTS side by side, see docs/tool-install.md)
  - git: 2.55.0
  - Microsoft365DSC module: not installed
  - prism: not installed
- Time taken: under 1 hour (skeleton docs only).
- Evidence: shell output in the Phase 0 Claude Code session; docs/tool-install.md lists target versions verified 2026-10-01.
- Change to the client plan, if any: None yet. Observation: Microsoft365DSC docs now require PowerShell 7.6+ but do not mention macOS or Linux support; Phase 7 may need a Windows GitHub Actions runner.
- Accepted risks added, if any: Azure CLI and the PowerShell cask install through Homebrew, which only offers the current version; versions are pinned by assertion (check block) and `brew pin`, not by exact install.

## 2026-10-01, Phase 0, Install block 1 run (stopped at PowerShell step)
- What the docs said: docs/tool-install.md install block downloads and checksum-verifies Terraform, SailPoint CLI, Conftest, and Node; installs Prism, Azure CLI, PowerShell 7 (as a Homebrew cask), and Microsoft365DSC; then writes `~/lab-tools/env.sh`.
- What actually happened:
  - Checksums OK: terraform_1.16.4_darwin_arm64.zip, sail_Darwin_arm64.tar.gz, conftest_0.71.0_Darwin_arm64.tar.gz, node-v24.21.0-darwin-arm64.tar.gz.
  - SailPoint CLI tarball holds the binary at `sail_Darwin_arm64/bin/sail`, not at the root; extract line changed to `--strip-components 2` before this run.
  - Prism 5.16.0 installed (210 packages). npm deprecation warnings for transitive deps uuid@8.3.2, json-schema-ref-parser@6.1.0, @faker-js/faker@5.5.3. npm skipped the `@scarf/scarf` postinstall script (install telemetry) because it is not allow-listed; left blocked on purpose.
  - Azure CLI 2.90.0 installed via Homebrew and pinned (`brew list --pinned` shows azure-cli). Side effect: Homebrew also installed libsodium 1.0.22 and upgraded readline 8.3.6 and xz 5.8.4.
  - Script stopped at `brew install --cask powershell`: "Cask 'powershell' is unavailable: No Cask with this name exists." PowerShell is now a Homebrew formula; `brew info powershell` shows formula 7.6.6 installed. The 2026-10-01 "Phase 0 started" entry calling it a cask was wrong.
  - Not done because the script stopped: Microsoft365DSC install, `~/lab-tools/env.sh`.
  - Spot check after the run: terraform v1.16.4, sail 2.6.0, conftest 0.71.0, node v24.21.0, az 2.90.0.
- Time taken: about 10 minutes.
- Evidence: terminal output pasted into the Claude Code session 2026-10-01; `~/lab-tools/bin` contains terraform, sail, conftest.
- Change to the client plan, if any: Install scripts must check Homebrew formula vs cask at run time; package type changes without notice.
- Accepted risks added, if any: Prism carries deprecated transitive npm packages (mock server only, local, no real data).

## 2026-10-01, Phase 0, Version check run before install finished
- What the docs said: docs/tool-install.md version check block sources `~/lab-tools/env.sh`, then prints each tool version for this log.
- What actually happened: The check ran before the two remaining install steps (Microsoft365DSC install, writing `~/lab-tools/env.sh`). Output:
  - `source`: no such file `~/lab-tools/env.sh`
  - terraform, sail, conftest, prism: "command not found" (binaries exist in `~/lab-tools/bin`, but that folder is not on PATH (the shell's search list) without env.sh)
  - az: 2.90.0
  - pwsh: PowerShell 7.6.6
  - Microsoft365DSC: "InvalidOperation: You cannot call a method on a null-valued expression." (module not installed)
  - node: v26.8.1 (Homebrew Node, not the lab's 24.21.0, because env.sh is missing)
  - git: 2.55.0
- Time taken: under 5 minutes.
- Evidence: terminal output pasted into the Claude Code session 2026-10-01; same result when Claude ran the check in its own shell.
- Change to the client plan, if any: The version check should test that env.sh exists first and print one clear "install incomplete" line, instead of a cascade of "command not found" errors.
- Accepted risks added, if any: None.

## 2026-10-01, Phase 0, Lab tools moved into the project folder
- What the docs said: docs/tool-install.md put pinned binaries in `~/lab-tools/`.
- What actually happened: Owner asked for the tools to live inside the project. Moved `~/lab-tools` (587 MB: bin, dl, node) to `~/Projects/okta-to-entra-migration/lab-tools/` with `mv`; nothing re-downloaded. Prism's link is relative, so it survived the move. Added `lab-tools/` to .gitignore; `git status` confirms it is not tracked. Updated every path in docs/tool-install.md. Entries above that say `~/lab-tools` describe the old location.
- Time taken: under 5 minutes.
- Evidence: `ls lab-tools` shows bin, dl, node; `git status --short` shows no lab-tools files.
- Change to the client plan, if any: None.
- Accepted risks added, if any: Tool binaries sit inside the repo folder; protected from commit only by .gitignore.

## 2026-10-01, Phase 0, Install finished, version check passed
- What the docs said: Phase 0 exit requires `terraform -version`, `sail --version`, `conftest --version` recorded here. docs/tool-install.md pins the versions below.
- What actually happened: Claude ran the two remaining steps locally (no cloud or provider API calls): wrote `lab-tools/env.sh`, and ran `Install-Module Microsoft365DSC -RequiredVersion 1.26.909.1 -Scope CurrentUser -Force` (15 seconds, no errors, no output). Version check after `source lab-tools/env.sh`:
  - terraform: Terraform v1.16.4
  - az: 2.90.0 (Homebrew, pinned)
  - sail: sail version 2.6.0
  - conftest: Conftest: 0.71.0
  - pwsh: PowerShell 7.6.6 (Homebrew formula)
  - Microsoft365DSC: 1.26.909.1
  - node: v24.21.0 (lab copy; `which node` resolves to lab-tools/node/bin)
  - prism: 5.16.0
  - git: 2.55.0
  All match the pinned versions in docs/tool-install.md. The three Phase 0 exit versions (terraform, sail, conftest) are recorded.
- Time taken: under 5 minutes.
- Evidence: version check output in the Claude Code session 2026-10-01; `brew list --pinned` shows azure-cli.
- Change to the client plan, if any: None. Microsoft365DSC installs on macOS; whether `Export-M365DSCConfiguration` runs on macOS is still UNVERIFIED until Phase 7.
- Accepted risks added, if any: None.

## 2026-10-01, Phase 0, Private GitHub repo created; environment gates not available on it
- What the docs said: CLAUDE.md says applies run only through GitHub Actions with environment gates, and secrets live in GitHub environment secrets. Before checking, Claude said (UNVERIFIED) that free-plan private repos lack required reviewers but GitHub Pro would fix it.
- What actually happened:
  - Owner approved; Claude ran `gh repo create mlencioni/okta-to-entra-migration --private --source . --remote origin --push`. Repo: https://github.com/mlencioni/okta-to-entra-migration, visibility PRIVATE, personal account (not a company org). Pushed `main` (commits 3c682fa, 61b87d6).
  - GitHub docs (deployments-and-environments reference, read 2026-10-01) say, for Free, Pro, and Team plans on private repos: required reviewers, wait timers, custom protection rules, and admin bypass are public-repo only. Free private repos also get no environment secrets, no environment variables, and no deployment branch restrictions; Pro or Team adds those three, but not reviewers. Claude's earlier "Pro fixes it" was wrong: reviewers on a private repo need GitHub Enterprise.
  - Account plan not confirmed (`gh api user --jq .plan.name` returned nothing with the current token scopes); assumed Free.
- Time taken: under 10 minutes.
- Evidence: `gh repo view --json visibility,url`; https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments
- Change to the client plan, if any: Decide before Phase 1 workflows: (a) make the lab repo public (nothing secret is committed; federated credentials need no stored secret), or (b) stay private and replace environment gates with branch protection plus a manual `workflow_dispatch` apply, with secrets at repo level. Client plan should state that environment-gated applies on private repos need GitHub Enterprise.
- Accepted risks added, if any: Until decided, the repo has no enforceable apply gate; no apply workflow exists yet, so no live exposure.

## 2026-10-01, Phase 0, Repo moved to lab org per docs/lab-naming.md
- What the docs said: docs/lab-naming.md and the plan put the repo at `iac-migration-lab/identity-as-code-lab`, public, in a free lab org, not under the owner's personal account.
- What actually happened:
  - Claude had created `mlencioni/okta-to-entra-migration` without reading docs/lab-naming.md (process miss; caught during the pre-public scan, before anything was public).
  - Pre-public scan of all tracked files and full history: no secrets, keys, or client names. Only personal data: owner's name and personal email as commit author on all commits.
  - Owner created org `iac-migration-lab` (Free plan) in the browser; owner is admin.
  - Claude transferred and renamed the repo with `gh api -X POST repos/mlencioni/okta-to-entra-migration/transfer -f new_owner=iac-migration-lab -f new_name=identity-as-code-lab`, and set `origin` to https://github.com/iac-migration-lab/identity-as-code-lab.git. Still PRIVATE.
  - Local folder name stays `okta-to-entra-migration`; only the GitHub name changed.
- Time taken: about 15 minutes.
- Evidence: `gh api repos/iac-migration-lab/identity-as-code-lab --jq '.full_name + " " + .visibility'` returned `iac-migration-lab/identity-as-code-lab private`.
- Change to the client plan, if any: Read the naming doc before creating any named resource.
- Accepted risks added, if any: None yet; author email decision pending before the repo goes public.

## 2026-10-01, Phase 0, Commit email rewritten, repo recreated, made public
- What the docs said: Plan and docs/lab-naming.md: repo is public (needed for free environment gates and environment secrets). No personal data in the repo.
- What actually happened:
  - Rewrote author and committer email on all commits to `mark@lencioni.io` with `git filter-branch --env-filter` (first to the GitHub noreply address, then to mark@lencioni.io at the owner's request). Dates and file contents unchanged (`git diff` against the pre-rewrite branch was empty). Repo-local `user.email` set to mark@lencioni.io. Force-pushed with `--force-with-lease`.
  - Finding: after the force-push, GitHub still served the old commits by SHA (the original commits returned the old personal email). A force-push does not remove commits from GitHub. Commit SHAs quoted in earlier entries (3c682fa, 61b87d6) were among them.
  - Fix: confirmed the repo held only `main` (0 forks, issues, releases, webhooks), owner added the `delete_repo` scope to the `gh` login, Claude ran `gh repo delete` then `gh repo create iac-migration-lab/identity-as-code-lab --private` and pushed `main`. All six old SHAs now return "No commit found". New history: ba98562, 2fb6215, d05e508, 53ef7ff, plus this entry.
  - Then set visibility to public.
  - Old SHAs in earlier entries of this log are now dead references; this entry maps them.
- Time taken: about 30 minutes, including a failed first `gh auth refresh`.
- Evidence: `gh api repos/iac-migration-lab/identity-as-code-lab/commits/<old sha>` returns 404 for 3c682fa, 61b87d6, 88d2358, d6eca41, 4ec1f3e.
- Change to the client plan, if any: To scrub data from a GitHub repo's history, rewriting plus force-pushing is not enough; delete and recreate the repo (or ask GitHub Support to purge) and check old SHAs before making it public. Set the commit email before the first commit.
- Accepted risks added, if any: Owner's name and mark@lencioni.io are public in commit metadata (accepted by owner).

## 2026-10-01, Phase 0, Lab email; company domain ruled out for Microsoft sign-ups
- What the docs said: Plan section 3: dedicated lab mailbox, "use a domain you control or a free Outlook address". CLAUDE.md: never reference or configure the owner's company Microsoft 365 tenant.
- What actually happened:
  - Owner proposed `okta-entra-mig@lencioni.io`. `dig MX lencioni.io` returned `lencioni-io.mail.protection.outlook.com`; owner confirmed lencioni.io is the company Microsoft 365 tenant.
  - Ruled out: creating the alias would configure the company tenant, and Microsoft would treat an `@lencioni.io` address on the Azure or Entra sign-up as an account in that tenant, so the lab subscription or admin roles could end up attached to it.
  - Owner created `la-migration-lab@outlook.com` (personal Microsoft account) for all lab sign-ups. Recorded in docs/lab-naming.md.
  - Okta sign-up page (https://developer.okta.com/signup/, read 2026-10-01) asks for "Work Email" and states no rule on free providers; whether it accepts outlook.com is still UNVERIFIED.
- Time taken: under 15 minutes.
- Evidence: MX lookup output in the Claude Code session 2026-10-01.
- Change to the client plan, if any: "A domain you control" is not enough: check that the domain is not a verified domain in any production Entra tenant before using it for Microsoft sign-ups. Check MX and ask the owner.
- Accepted risks added, if any: Lab email address is in the public repo (spam and phishing target); it protects only throwaway lab accounts. Use MFA on it.

## 2026-10-01, Phase 0, Okta org created with the owner's work email
- What the docs said: Plan section 3: Okta needs a unique business email per org, so use a domain you control or a free Outlook address. Lab email is `la-migration-lab@outlook.com`.
- What actually happened:
  - Okta Integrator Free Plan sign-up rejected `la-migration-lab@outlook.com` (exact error text not captured). The plan's "free Outlook address" option does not work.
  - Owner signed up with `mark@lencioni.io` instead. Org: `integrator-2631921`; Admin Console https://integrator-2631921-admin.okta.com/; org URL https://integrator-2631921.okta.com.
  - Hard-rule check: no change was made to the company Microsoft 365 tenant. The address already existed; only Okta's sign-up and activation emails go to that mailbox. Not a breach of CLAUDE.md, but the Okta super admin now uses the owner's work identity.
- Time taken: under 15 minutes.
- Evidence: Org URL supplied by the owner 2026-10-01.
- Change to the client plan, if any: Free email providers fail Okta's "Work Email" check; lab staff need an address on a domain that is not tied to any production tenant. Budget a cheap throwaway domain if a clean separation is required.
- Accepted risks added, if any: Okta lab super admin uses `mark@lencioni.io`. Never connect this Okta org to the lencioni.io tenant (no Microsoft IdP, no Org2Org, no SCIM toward lencioni.io). That address can no longer sign up for another Integrator org (unique email per org). Enroll MFA on the Okta admin.

## 2026-10-01, Phase 0, Azure account created; no spending limit
- What the docs said: Plan section 2: Azure free account, $200 credit for 30 days, credit card required, Terraform state storage costs pennies.
- What actually happened:
  - Owner signed up as `la-migration-lab@outlook.com` in a private browser window. `az login` shows one subscription, `Azure subscription 1` (6ea51c80-90de-4914-bbc6-2af9b54bba9f), in tenant `Default Directory` (bed5d4c3-98f0-4c73-9e4c-0b6cd3b9a0a4).
  - Read-only Graph check: the tenant's only verified domain is `lamigrationlaboutlook.onmicrosoft.com`. No link to lencioni.io.
  - Read-only Azure Resource Manager check: offer `PayAsYouGo_2014-09-01`, spending limit `Off`. Usage past the credit bills the card with no automatic stop. The plan assumed a capped free-trial offer.
  - Microsoft Learn "Access and create new tenant" (updated 2026-08-21) says only paid customers can create a new workforce tenant and that free-tenant or trial-subscription customers cannot. A Pay-As-You-Go offer suggests creating the lab tenant is allowed; UNVERIFIED until tried.
- Time taken: about 20 minutes.
- Evidence: `az account show`, `az rest` GET on /organization and on the subscription, Claude Code session 2026-10-01.
- Change to the client plan, if any: Before any spend, check the subscription offer and spending limit; set a budget alert on day one.
- Accepted risks added, if any: No spending cap on the lab subscription until a budget alert exists.

## 2026-10-01, Phase 0, Lab Entra tenant is the Azure Default Directory
- What the docs said: Plan Phase 0: create a new Entra tenant. docs/lab-naming.md: `iacmigrationlab.onmicrosoft.com`. Microsoft Learn "Access and create new tenant" (updated 2026-08-21): only paid customers can create a new workforce tenant; if **Microsoft Entra ID** is unavailable on the Basics tab, review the paid-customer requirement.
- What actually happened:
  - First attempt reported success, but only `Default Directory` existed (checked with a read-only ARM `/tenants` call and in the portal's Directories + subscriptions).
  - Read-only check of the subscription, resource groups, resources, and 24-hour activity log: nothing extra created.
  - On retry, **Manage tenants** > **Create** offered only **Governed Workforce** and **External**; plain **Microsoft Entra ID** was missing, even though the subscription offer is Pay-As-You-Go.
  - Governed Workforce rejected: it creates a resource group and billing asset and a permanent governance link to the home tenant, none of which the plan covers. External is for customer identity (CIAM), wrong type.
  - Owner chose to use the Default Directory (`lamigrationlaboutlook.onmicrosoft.com`, tenant ID bed5d4c3-98f0-4c73-9e4c-0b6cd3b9a0a4) as the lab tenant. docs/lab-naming.md updated: initial domain, break-glass UPN `bg-admin-01@lamigrationlaboutlook.onmicrosoft.com`. Display name to be renamed to `IaC Migration Lab` by the owner.
- Time taken: about 30 minutes.
- Evidence: `az rest` GET https://management.azure.com/tenants, `az account list --all`, `az group list`, `az resource list`, `az monitor activity-log list --offset 1d`, Claude Code session 2026-10-01; owner's portal observations.
- Change to the client plan, if any: A new Azure Pay-As-You-Go account cannot create an extra plain workforce tenant (UNVERIFIED whether this changes after the first paid invoice). Labs should plan on the sign-up Default Directory as the test tenant.
- Accepted risks added, if any: The Azure subscription that will hold Terraform state lives in the same tenant as the lab's Conditional Access policies; a bad CA policy can lock the owner out of the state storage too. Break-glass exclusion (module + Conftest rule) covers this; the owner account `la-migration-lab@outlook.com` is a personal Microsoft account and should also be excluded from CA policies in the lab.

## 2026-10-01, Phase 0, Budget alert on the lab subscription
- What the docs said: Previous entry: no spending cap until a budget alert exists.
- What actually happened: Owner approved. Claude created `budget-iac-lab-monthly` on subscription 6ea51c80-90de-4914-bbc6-2af9b54bba9f with `az rest --method put` to `Microsoft.Consumption/budgets` (api-version 2023-05-01): Cost category, $10 monthly, 2026-10-01 to 2027-09-30, actual-cost email alerts at 50/80/100% to `la-migration-lab@outlook.com`. Created by hand, not by Terraform; import it when the Azure state stack exists, or recreate it in code.
- Time taken: under 5 minutes.
- Evidence: PUT response returned name, amount 10.0, Monthly, three notifications.
- Change to the client plan, if any: None.
- Accepted risks added, if any: The budget alerts but cannot stop spend; the "no spending cap" risk is reduced, not closed.

## 2026-10-01, Phase 0, ServiceNow PDI unavailable; change gate made ITSM-agnostic
- What the docs said: Plan: ServiceNow Personal Developer Instance (PDI) for the Phase 3 change gate (`table/change_request` API).
- What actually happened: ServiceNow developer sign-up said no instances were available to join the waiting list. Owner chose to skip ServiceNow and design the change gate for any ITSM (IT Service Management) tool. New design in docs/change-gate-design.md: PR body names `Change: <system>:<id>`, one read-only adapter per ITSM returns a normalized record (state, window), and one shared check enforces it. Lab adapter uses GitHub Issues (labels for state, body lines for the window, `GITHUB_TOKEN` with `issues: read`). Plan and workflow placeholder updated to match.
- Time taken: under 15 minutes.
- Evidence: owner report of the ServiceNow sign-up message, 2026-10-01 (exact text not captured).
- Change to the client plan, if any: Change gate becomes ITSM-agnostic; the client's tool plugs in as an adapter. The ServiceNow-specific REST call and state mapping are now unvalidated in the lab and must be confirmed against the client's instance.
- Accepted risks added, if any: GitHub Issues as change records give no segregation of duties (any writer can relabel); the lab proves pipeline mechanics only.

## 2026-10-01, Phase 0, Exit check passed; Phase 0 closed
- What the docs said: Phase 0 exit: every account reachable; `terraform -version`, `sail --version`, `conftest --version` recorded in this log.
- What actually happened (all checks read-only):
  - GitHub: `iac-migration-lab/identity-as-code-lab`, PUBLIC, default branch `main`, local in sync with origin.
  - Azure: signed in as `la-migration-lab@outlook.com`; `Azure subscription 1` (6ea51c80-90de-4914-bbc6-2af9b54bba9f) Enabled; budget `budget-iac-lab-monthly` $10, current spend $0.00.
  - Entra: tenant bed5d4c3-98f0-4c73-9e4c-0b6cd3b9a0a4, display name `IaC Migration Lab` (owner renamed it), domain `lamigrationlaboutlook.onmicrosoft.com`. P2 trial not activated.
  - Okta: `https://integrator-2631921.okta.com/.well-known/openid-configuration` returned HTTP 200 with issuer `https://integrator-2631921.okta.com`; owner has signed in to the Admin Console. Okta management API not tested yet (no service app until Phase 1).
  - ITSM: none; GitHub Issues stand-in needs no account (see docs/change-gate-design.md).
  - Tools: Terraform v1.16.4, sail version 2.6.0, Conftest 0.71.0 (full list in the "Install finished" entry).
  - Repo layout matches the plan.
- Time taken: Phase 0 total about 4 hours in one evening (plan said one evening).
- Evidence: `gh repo view`, `az account show`, Graph GET /organization, Consumption budget GET, curl to the Okta OpenID Connect discovery URL, tool version commands; Claude Code session 2026-10-01.
- Change to the client plan, if any: Phase 0 changes are in the entries above: Okta rejects free email providers; a new Azure account cannot create a second workforce tenant; Azure free account is Pay-As-You-Go with no spending limit; ServiceNow PDI unavailable; GitHub repo must be public for free environment gates and environment secrets.
- Accepted risks added, if any: None new.

Current phase set to 1 at the top of this log.

## 2026-10-07, Run 1, Lab Phase 1, Lab reframed as Implementation Phase 0; permissions opened up
- What the docs said: CLAUDE.md required a least-privilege block and owner approval before every grant, cloud change, or write API call; no SSWS tokens; no local `terraform apply`.
- What actually happened: Owner named this lab "Claude Identity as Code Implementation Phase 0" (IP0): personal free accounts and dummy data, to learn the CI/CD pipelines and migration code. Owner will run IP0 at least three times; run 1 goal is to see it all work. Owner pre-approved any permission and any lab resource change. CLAUDE.md rewritten: the least-privilege gate is replaced by docs/permission-register.md (every grant logged with a production verdict); local apply allowed for bootstrap and to get unstuck; isolation from `lencioni.io` and no-secrets-in-repo stay absolute. Plan phases are now "lab phases". Added docs/migration-runbook.md (skeleton). Added docs/okta-seed-spec.md and okta-inventory/seed/seed-okta-org.sh (not run yet). SAML test SP chosen: `sptest.iamshowcase.com` (samltest.id is down).
- Time taken: about 30 minutes.
- Evidence: this commit.
- Change to the client plan, if any: Production permissions come from the register's "Production should use" column, not from the lab.
- Accepted risks added, if any: Lab identities may hold broader grants than production would allow; each is listed in the register.

## 2026-10-15, Run 1, Lab Phase 1, Run 1 scope adopted; second repo not used
- What the docs said: docs/run-1-scope.md (decided 2026-10-05, written 2026-10-07) narrows run 1. Before it, run 1 meant all of Lab Phases 1 to 8.
- What actually happened: Scope adopted. CLAUDE.md now lists docs/run-1-scope.md first under "Read first, every session". docs/build-phases.md headings mark Lab Phases 5, 6, 7 deferred and note Lab Phase 8 runs as Lab Phase 5 in run 1; step text unchanged.
  - Three proof points: (1) Okta discovery as code, read-only (import, generate-config, normalize, nightly snapshot, drift, no PII (personally identifiable information) in Git); (2) Entra write path as code (brownfield import with zero diff, Okta SAML and OIDC apps translated into working Entra apps); (3) CI/CD between the two (plan, policy, change gate, nonprod on merge, prod behind a reviewer, federated credentials, drift issue, one wave and one rollback).
  - Deferred: SailPoint stand-in (Lab Phase 5), msgraph gap layer (Lab Phase 6; the Lab Phase 2 claims experiment still tries msgraph on one app), Microsoft365DSC snapshot (Lab Phase 7), multi-tenant Entra model. Nothing deleted; run 2 or 3 can pick them up.
  - Second repo: `mlencioni/okta-to-entra-migration-factory` (private, personal account, created 2026-10-05) is not used. On the GitHub Free plan a private repo has no required reviewers and no environment secrets, so it cannot carry the `prod` gate or per-environment federated-credential subjects (see 2026-10-01 "Private GitHub repo created"). Checked today: it still exists (PRIVATE). Owner deletes it.
  - Stray local folder `~/okta-entra-migration` (duplicate Lab Phase 0 run on 2026-10-05, two commits, no remote): still present today. Owner deletes it; nothing in it is needed.
  - Multi-tenant hook: every Entra root module takes `tenant_key` (`lab` in run 1) and `tenant_id` and reads nothing else about the tenant; state keys and workflow matrix entries come from `tenant_key`; CA (Conditional Access) names follow `<TENANT>-CA<NN> - <Apps> - <Control> - <Persona> - <Conditions>`. A new tenant becomes a map entry plus a federated credential.
  - Revisit trigger (run-1-scope.md section 7): run 2 replaces every "Not OK" permission-register row with the production-shaped grant; run 3 must be production-shaped end to end, or the runbook says why not.
  - Added `.claude/` (Claude Code local settings) to .gitignore.
- Time taken: about 10 minutes.
- Evidence: this commit; `gh repo view mlencioni/okta-to-entra-migration-factory` returned PRIVATE; `ls -d ~/okta-entra-migration` found the folder.
- Change to the client plan, if any: Client build sequencing can treat SailPoint, the msgraph gap layer, and DSC (Desired State Configuration) as later increments; the multi-tenant variables are in from the first module.
- Accepted risks added, if any: None new; the section 7 list in docs/run-1-scope.md stands.

## 2026-10-15, Run 1, Lab Phase 1, Repo renamed to okta-to-entra-migration-factory
- What the docs said: docs/run-1-scope.md section 3: if the "migration factory" name is wanted, rename this repo in place before Lab Phase 3 creates federated-credential subjects, which contain the repo name.
- What actually happened: Owner chose to rename now. Claude ran `gh repo rename okta-to-entra-migration-factory -R iac-migration-lab/identity-as-code-lab --yes` and set `origin` to https://github.com/iac-migration-lab/okta-to-entra-migration-factory.git. No federated credential or app registration exists yet, so nothing in Entra needed changing. Updated forward-looking docs: run-1-scope.md, lab-naming.md, claude-code-prompts.md, start-phase-1.md, poc-plan-identity-as-code-free-tier.md, build-phases.md (Lab Phase 3 subjects). Left as-run history unchanged: earlier findings entries and the Lab Phase 0 "Steps as run" in build-phases.md. The private repo `mlencioni/okta-to-entra-migration-factory` has the same name under a different owner; no conflict, owner still deletes it.
- Time taken: under 5 minutes.
- Evidence: `gh repo view iac-migration-lab/okta-to-entra-migration-factory` returned PUBLIC, default branch `main`; `git fetch` against the new origin succeeded.
- Change to the client plan, if any: Fix the repo name before creating any federated credential; a later rename means re-creating every subject.
- Accepted risks added, if any: GitHub redirects the old URL until a new repo takes the old name; the local clone folder keeps its old name (`~/Projects/okta-to-entra-migration`).

## 2026-10-16, Run 1, Lab Phase 1, Okta org seeded; reader identity created
- What the docs said: docs/okta-seed-spec.md: seed with `okta-inventory/seed/seed-okta-org.sh` (dry run, then `--apply`) using SSWS token `iac-run1-seed`, smoke test as Ada, then create `iac-okta-reader` (API Services, private key JWT, seven read scopes, Read-only Administrator) per docs/build-phases.md Lab Phase 1 step 2.
- What actually happened:
  - Token file: `~/.okta-lab/ssws-token` (register #4) did not exist; the token had been saved as `~/.okta-lab/iac-okta-seeder.pem`, which at first held a pasted shell command. Owner fixed the contents; Claude renamed it to `ssws-token` (600) without reading it.
  - First dry run failed: a multi-line paste split `export` from its variables (fix: one command per line). The stray `export` printed the owner's environment, which included an unrelated work API key; owner advised to rotate it. Nothing from it went into the repo.
  - Dry run clean (45 planned writes). Apply: 42 OK, 3 failed.
    - `iac-pwd-staff`: Identity Engine rejected the policy because the security question authenticator is disabled (`Api validation failed: mediationPolicy`); a partial recovery block then returned HTTP 500. Fixed by sending the full recovery block as the Default Policy has it (`recovery_question` INACTIVE with properties, `okta_email` ACTIVE). Its rule failed only because the policy did not exist.
    - Catch-all rule of `iac-authn-saml-apps`: HTTP 403 E0000077 "conditions read-only", with conditions omitted or `{}`. Accepted only with `system: true`, `priority: 99`, `conditions: null`. Default catch-all was phishing-resistant 2FA; now password only per the spec.
    - Claude created the password policy and its rule and fixed the catch-all directly with the SSWS token (local API calls, logged here), then updated the script so a dry run reports 0 failures.
  - Smoke test, first attempt: 403 at the Admin Console (wrong URL, `-admin`). Second: "Unable to sign in"; system log showed `ENROLL` on the built-in Okta Dashboard policy, whose catch-all required 2FA while the only second factor (Okta Verify) cannot be enrolled by a new user. Claude set the Okta Dashboard catch-all to password only (local API call; added to the seed script). This is a change to a built-in policy the inventory will import.
  - Seeded passwords did not match 1Password (the hidden prompt got a multi-paste). Ada recovered by email self-service reset (proves `iac-pwd-staff-rule`); new `okta-inventory/seed/reset-seed-passwords.sh` (password asked twice, must match) set the other 7 active users; `passwordChanged` confirmed for all 7.
  - Smoke test results: Ada: sign-in pass; `iac-saml-it-tools` NameID pass; `iac-saml-hr-portal` attributes `department`, `title`, `employeeNumber`, `groups` pass. Cara (IT + CustServ): sign-in pass, SAML apps pass. `iac-oidc-portal` has no dashboard tile: an OIDC app with no `initiate_login_uri` (login mode DISABLED) is hidden by design; OIDC sign-in is tested via oidcdebugger in Lab Phase 2.
  - Unverified items resolved: Okta accepts `.example` logins and plus-addressed emails; the OIN Slack app created with name `slack` and `settings.app.domain`.
  - `iac-okta-reader` created with the SSWS token via API: app ID / client ID `0oa18siafpuScaofm698`, key ID `iac-okta-reader-2026-10-16` (RSA 2048, generated on the owner's Mac; private key in `~/.okta-lab/iac-okta-reader.pem` and 1Password; Claude read only the public key). Seven scopes granted, Read-only Administrator assigned. Register row #5.
  - Read check as `iac-okta-reader` (`okta-inventory/verify-reader.sh`, no SSWS), compared with the seed spec:

    | Object | Seen by reader | Expected |
    |---|---|---|
    | Users | 9 ACTIVE (8 seeded + admin), 1 DEPROVISIONED | 8 + 1 + admin |
    | Groups | IT, CustServ, Finance (5 total with built-ins) | 3 custom |
    | Apps | 6 seeded + `iac-okta-reader` (7 total) | 6 |
    | Network zones | HTTP 403 | 1 custom |
    | Password / global session / authentication policies | `iac-pwd-staff`, `iac-gsp-staff`, `iac-authn-saml-apps` (+ built-ins) | 1 each |
    | Authorization servers | `default`, `iac-authz-api` | 1 + default |
    | Identity providers | 0 | 0 |
    | Write (create group) | HTTP 403 | refused |

  - The reader's app list is 7, while the SSWS token sees 13: Okta's built-in apps (Admin Console, Dashboard, Workflows and others) are not returned to the OAuth reader.
- Time taken: seeding 22:06:45 to about 22:22 MDT on 2026-10-15 (about 15 minutes, including the two fixes). Smoke test troubleshooting and password reset about 40 minutes. Reader identity and read check about 15 minutes.
- Evidence: seed script output (owner session); Okta system log events `policy.evaluate_sign_on` ENROLL and `app.generic.unauth_app_access_attempt` (2026-10-16 06:42 to 07:07 UTC); users API `passwordChanged` 07:20:46 to 07:20:48 UTC; `verify-reader.sh` output above.
- Change to the client plan, if any: (1) Inventory scopes must include `okta.networkZones.read`; the build-phases list of seven does not, and zones return 403. (2) Built-in Okta apps are invisible to the read-only OAuth identity; decide whether the inventory needs them. (3) Brownfield import will see admin-modified built-in policies (Okta Dashboard catch-all); expect that in the client org too. (4) New users without an enrolled factor cannot pass a 2FA catch-all; the client migration needs a first-factor enrollment path.
- Accepted risks added, if any: Okta Dashboard sign-in is password only in the lab org.

## 2026-10-16, Run 1, Lab Phase 1, Okta inventory imported and normalized
- What the docs said: docs/build-phases.md Lab Phase 1 steps 3 to 5: `okta/okta` `~> 7.0`, OAuth service app auth, one import block per object, `-generate-config-out`, normalize into modules, time each app, list every wrong attribute; goal zero changes.
- What actually happened:
  - Versions: Terraform 1.16.4, `okta/okta` 7.0.0 (newest release on 2026-10-16). Pinned `= 7.0.0` because `.terraform.lock.hcl` is git-ignored, so `~> 7.0` would float.
  - Provider arguments `org_name`, `base_url`, `client_id`, `private_key_id`, `private_key`, `scopes`, `max_api_capacity` checked against the 7.0.0 schema. `private_key` accepts a file path (`OKTA_API_PRIVATE_KEY=~/.okta-lab/iac-okta-reader.pem`), so the key never enters an environment variable or a repo file.
  - Added scope `okta.networkZones.read` to `iac-okta-reader` (register #6). Okta returned HTTP 400 to the grant call but created the grant; a retry said "already granted". The earlier zones 403 came from the missing grant.
  - 29 import blocks: 3 groups, 6 apps, 6 app group assignments, 1 zone, password/global session/authentication policies with 5 rules, authorization server with scope, claim, policy, rule. **Deviation from the session prompt:** users (9) and group memberships are not imported. They are personal data, and proof point 1 keeps PII out of Git; the snapshot sends them to Azure Blob. Run 2: decide whether the client inventory wants users in state at all.
  - First generate-config plan: 29 to import, 2 to change, 1 second. Normalized into one file per object type and one per app (app plus its group assignments), references instead of IDs, nulls removed. **Shortcut:** files in the root module, not child modules; run 2 moves them into modules (needs `moved` blocks).
  - Import-only apply into local state (no-op 29, read-only identity, so it cannot write to Okta). `terraform plan -detailed-exitcode` then exit 0, "No changes." Run 1 definition of done item 1 met.
  - Generator errors and diffs:

    | Object | Generated | Fix |
    |---|---|---|
    | 4 custom SAML apps | `preconfigured_app = "integrator-2631921_<app>_1"` (internal app name, as if OIN) | Removed; no diff |
    | All SAML apps | `app_links_json` keyed by the org-specific app name | Removed; no diff |
    | All objects | Literal IDs for groups, zone, policies, auth server, OIDC client | Replaced with references |
    | Most objects | Dozens of `= null` arguments | Removed |
    | `iac-oidc-portal` | `client_basic_secret` and `client_basic_secret_wo` lines marked sensitive (null) | Removed |
    | `iac-oidc-portal` | `omit_secret`, `refresh_token_leeway`, `refresh_token_rotation`, `skip_authentication_policy` null; plan sets defaults whether stated or not; `skip_authentication_policy` conflicts with `authentication_policy` | `lifecycle.ignore_changes` on the four |
    | Catch-all rule of `iac-authn-saml-apps` | `network_connection = null`; plan sets `ANYWHERE` whether stated or not (API returns `conditions: null` for system rules) | `lifecycle.ignore_changes = [network_connection]` |
    | Policy rule `constraints` | Escaped JSON strings | `jsonencode()` |
    | Slack (OIN) | No noise in plan with `preconfigured_app = "slack"`, `app_settings_json` domain | None needed; the predicted `okta_app_saml` drift did not appear on 7.0.0 |

  - Apps not mapped to `iac-authn-saml-apps` (Slack, OIDC) use the built-in default authentication policy `rst188pzg3iEP5uGh698`, kept as a literal in `local.default_app_signon_policy_id` because built-ins are not imported.
- Time taken: about 40 minutes for the session. Normalization minutes per app, Claude-assisted (model writes, plan checks): it-tools 1 (pattern set here), custserv-desk under 0.5, finance-ledger under 0.5 (both copied from it-tools), hr-portal 0.5, Slack 0.3, OIDC 1 (two plan rounds). Shared objects about 1. These are not human estimates: the client number needs a person reviewing and owning each file; time that in run 2.
- Evidence: plan output "Plan: 29 to import, 0 to add, 0 to change, 0 to destroy", apply "29 imported", then `plan -detailed-exitcode` exit 0; `terraform state list` 29 entries; `okta-inventory/*.tf`.
- Change to the client plan, if any: Budget normalization per app type, not per app: the first app of each type takes the time, the rest are near copies. Expect `ignore_changes` for import-default artifacts on OAuth apps and for system catch-all rules. Add `okta.networkZones.read` to the inventory scope list.
- Accepted risks added, if any: Local `terraform.tfstate` (git-ignored) holds app and policy settings until it moves to Azure Storage in the next session.

## 2026-10-16, Run 1, Lab Phase 1, Snapshot green; drift detected
- What the docs said: docs/claude-code-prompts.md Session 3: `rg-iac-lab`, `stiaclabtfstate` with containers, `iac-reader` with a federated credential for `ref:refs/heads/main`, state moved to azurerm, `snapshot.yml` with counts to Git and user JSON to Blob, then one induced drift.
- What actually happened:
  - Azure CLI token blocked by security defaults (AADSTS530035). Device-code sign-in was refused ("You don't have access to this"); browser sign-in in a private window worked. CLI subscription picker turned off (`core.login_experience_v2=off`) so `! az login` runs unattended.
  - `rg-iac-lab` in `westus3`. Storage failed with "SubscriptionNotFound": the `Microsoft.Storage` resource provider was not registered on the new subscription; registered it. `stiaclabtfstate` and `stiaclabtfstate01` were taken globally; created `stiaclabtfstate02` (Standard_LRS, versioning, 7-day blob and container soft delete, shared-key access off, public blob access off, TLS 1.2). Containers `tfstate-nonprod`, `tfstate-prod`, `okta-exports`.
  - `iac-reader` app registration (appId `9355f439-af11-4299-a863-64a2b3e49c19`), no client secret. Federated credential subject is the GitHub environment `okta-read` (the snapshot job needs that environment for the Okta key), not `ref:refs/heads/main` as the scope doc said.
  - First run failed at `azure/login`: AADSTS700213. The repo has `use_immutable_subject: true`, so GitHub sends `repo:iac-migration-lab@336396784/okta-to-entra-migration-factory@1399352055:environment:okta-read`. Updated the credential (register #12) and every planned subject in the docs. UNVERIFIED: whether a repo rename still breaks the subject (the names are still in it).
  - Roles: `iac-reader` Storage Blob Data Contributor on `tfstate-prod` and `okta-exports`; owner on the account (shared keys off) (register #8 to #10). Environment `okta-read`: four variables set by Claude, secret `OKTA_PRIVATE_KEY` loaded by the owner (register #11).
  - State: `backend.tf` (azurerm, `use_azuread_auth`), `terraform init -migrate-state` with the owner's CLI login; 29 resources, plan still exit 0; local `terraform.tfstate` and backup deleted.
  - `snapshot.yml`: nightly 09:17 UTC plus manual; actions pinned by SHA (`actions/checkout` v7.0.1, `azure/login` v3.1.0 with `allow-no-subscriptions`, `hashicorp/setup-terraform` v4.0.1, Terraform 1.16.4); plan `-detailed-exitcode -lock=false`; `okta-inventory/snapshot-export.sh` writes counts to `docs/inventory-counts.md` (committed only when a count changes) and users, group members, app assignments to Blob `okta-exports/<date>/<run>/`.
  - Green run: https://github.com/iac-migration-lab/okta-to-entra-migration-factory/actions/runs/38875055268 (plan exit 0; counts committed as `f3e1852`; three JSON files in Blob).
  - Drift: owner changed the Finance group description in the Admin Console. Run https://github.com/iac-migration-lab/okta-to-entra-migration-factory/actions/runs/38875619039 failed at "Fail on drift" (plan exit 2); plan shows `okta_group.finance` `description = "Finance Team" -> "Finance"`.
- Time taken: about 50 minutes, most of it sign-in, provider registration, and the subject format.
- Evidence: the two run URLs; `az storage blob list` of `okta-exports`; `gh api repos/.../actions/oidc/customization/sub` returned `use_immutable_subject: true`.
- Change to the client plan, if any: Read the GitHub OIDC subject format from the repo before writing any federated credential. Register resource providers as a bootstrap step. Check storage name availability first. Expect security defaults to force browser sign-in for CLI bootstrap. A job that uses a GitHub environment needs an environment subject, not a branch subject.
- Accepted risks added, if any: The nightly export keeps dummy user JSON in Blob with no retention policy yet.
- What to check after the next nightly run: the owner sets the Finance description back to `Finance`; the 09:17 UTC run on 2026-10-17 must be green (plan exit 0). Then a second green nightly closes Lab Phase 1 (exit criterion: green two nights running).
