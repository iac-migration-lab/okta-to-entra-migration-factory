# Porting Guide: Move This Repo to a New Lab

How to take this repo to a new set of accounts (a new Okta org, Entra tenant, Azure subscription and GitHub org) and get it working there. Written for building the next lab from this one.

Read with:
- [build-by-hand.md](build-by-hand.md): the full build, step by step, with no AI assistant.
- [lab-naming.md](lab-naming.md): the names this lab uses.
- [okta-identity-engine-decision.md](okta-identity-engine-decision.md): the new Okta org must run Identity Engine.

**Your computer:** written for Windows 10 or 11 through WSL2 (Windows Subsystem for Linux, version 2). Set up WSL2, Ubuntu 24.04 and the tools first (build-by-hand part 2). Run every `bash` block below in the **Ubuntu** terminal, not PowerShell, and keep the repo inside Ubuntu's home folder (`~/Projects/...`), never under `/mnt/c/...`. The repo's `.gitattributes` keeps Linux line endings, so the bash scripts run unchanged.

## 1. What moves and what does not

| Thing | Moves? | Why |
|---|---|---|
| Code layout, workflows, scripts, policy rules, docs | **Yes**, copy as is | Generic once the values in section 3 are replaced |
| Environment values (org names, tenant ID, storage account, IDs) | **Replace** | Section 3 lists every one, with its file |
| `okta-inventory/imports.tf` and `okta-inventory/*.tf` object IDs | **Regenerate** | Okta object IDs are unique per org; the seed makes new ones |
| `entra/legacy/` imports and IDs | **Regenerate** | The brownfield objects are built by hand in each tenant, with new IDs |
| `entra/platform/`, `entra/waves/` | **Yes**, apply fresh | They create their objects; only tfvars and a few IDs change |
| Terraform state | **No** | Never copy state. The new storage account starts empty |
| Secrets (Okta private key, passwords) | **No** | Create new ones in the new accounts; never in Git |
| Findings log, permission register, evidence | **Archive, then start fresh** | They describe the old lab. Keep them as history (section 2) |
| Git history | Your choice | It holds the old lab's IDs (not secrets). A fresh history is cleaner (section 2) |

## 2. Copy the repo

Recommended: a fresh repo with a clean history, keeping the old lab's docs as an archive.

```bash
# 1. Copy the files without the old history (Ubuntu terminal; ~ is /home/<linux-user>)
mkdir -p ~/Projects
git clone https://github.com/iac-migration-lab/okta-to-entra-migration-factory.git ~/Projects/<new-repo>
cd ~/Projects/<new-repo>
rm -rf .git
git init -b main

# 2. Archive the old lab's records, then start empty ones
mkdir -p docs/archive/lab-1
mv docs/findings-log.md docs/permission-register.md docs/inventory-counts.md docs/evidence docs/archive/lab-1/
```

Then create new, empty `docs/findings-log.md` and `docs/permission-register.md` from the headers and templates at the top of the archived copies, and an empty `docs/evidence/` folder.

The old lab's count history is on its `inventory-counts` branch, which a clone of `main` does not bring. The new repo's first snapshot run creates its own `inventory-counts` branch; leave that branch unprotected.

Alternative: keep the history (`git clone` and change `origin`). Fine for a personal lab; the old IDs stay in history.

Create the new GitHub repo **in a GitHub organization, public** (free private repos have no environment reviewers or environment secrets), then push:

```bash
gh repo create <new-org>/<new-repo> --public --source . --push
```

Read the new repo's numeric IDs now; they go into every federated credential (section 4):

```bash
gh api orgs/<new-org> --jq .id
gh api repos/<new-org>/<new-repo> --jq .id
gh api repos/<new-org>/<new-repo>/actions/oidc/customization/sub
```

## 3. Every value to replace

Collect the new values first (fill in the right-hand column), then replace them file by file. Edit in VS Code (Visual Studio Code) with the WSL extension (`code .` from the repo folder in Ubuntu), not Windows Notepad, which can save Windows line endings into the scripts.

### 3.1 Values you choose or get at sign-up

| Value | Lab 1 value | Files | New value |
|---|---|---|---|
| Okta org name | `integrator-2631921` | `okta-inventory/providers.tf` (`org_name`), `.github/workflows/snapshot.yml` (`OKTA_ORG_URL`), `okta-inventory/seed/seed-okta-org.sh` (comment) | |
| Okta base URL | `okta.com` | `okta-inventory/providers.tf` (`base_url`) | |
| Okta reader client ID | `0oa18siafpuScaofm698` | `okta-inventory/providers.tf` (`client_id`); GitHub variable `OKTA_CLIENT_ID` | |
| Okta reader key ID | `iac-okta-reader-2026-10-16` | GitHub variable `OKTA_KEY_ID`; local `OKTA_API_PRIVATE_KEY_ID` | |
| Okta cutover client ID and key ID | `0oa1965gqj5LStpWJ698`, `iac-okta-cutover-2026-10-26` | GitHub environment `okta-cutover` variables `OKTA_CUTOVER_CLIENT_ID`, `OKTA_CUTOVER_KEY_ID` | Create the app first (build-by-hand, Lab Phase 4 note) |
| Okta wave app and group IDs | `0oa18sc4rb0oNOWxW698`, `00g18sc4r6df83yDe698`, … | `.github/okta-cutover-apps.json`; org URL in `.github/workflows/okta-cutover.yml` | Copy from `okta-inventory/imports.tf` after regenerating it |
| Okta test user login domain | `iaclab.example` | `okta-inventory/seed/seed-okta-org.sh` (`LOGIN_DOMAIN`), `okta-inventory/seed/reset-seed-passwords.sh` | |
| Lab mailbox (seed user emails, budget alerts) | `la-migration-lab` @ `outlook.com` | `okta-inventory/seed/seed-okta-org.sh` (`MAIL_BASE`, `MAIL_DOMAIN`), `azure/bootstrap/budget.tf` (`contact_emails`) | |
| Entra tenant ID | `bed5d4c3-98f0-4c73-9e4c-0b6cd3b9a0a4` | `entra/legacy/tenants/lab.tfvars`, `entra/platform/tenants/lab.tfvars` and `lab-np.tfvars`, `entra/waves/wave-00/tenants/lab.tfvars` and `lab-np.tfvars`, `entra/waves/wave-01/tenants/lab.tfvars` and `lab-np.tfvars`; GitHub variable `AZURE_TENANT_ID` | |
| Entra tenant domain | `lamigrationlaboutlook.onmicrosoft.com` | Test user names (created by hand, section 5 of build-by-hand) | |
| Azure subscription ID | `6ea51c80-90de-4914-bbc6-2af9b54bba9f` | `azure/bootstrap/providers.tf`, `azure/bootstrap/budget.tf` (two places) | |
| Azure resource group | `rg-iac-lab` | Creation commands only | |
| Storage account (globally unique) | `stiaclabtfstate02` | Every `backend.tf` (`okta-inventory/`, `azure/bootstrap/`, `entra/legacy/`, `entra/platform/`, `entra/waves/wave-00/`, `entra/waves/wave-01/`), `.github/workflows/snapshot.yml` (`--account-name`) | |
| State containers | `tfstate-prod`, `tfstate-nonprod`, `okta-exports` | Keep the names (they are also in `.github/scripts/tf-roots.sh`) unless you have a reason | |
| GitHub org / repo | `iac-migration-lab` / `okta-to-entra-migration-factory` | Federated credential subjects; `docs/git-check-plans-info.md` commands; README; `docs/inventory-counts.md` (link to the counts branch) | |
| GitHub org ID / repo ID | `336396784` / `1399352055` | Federated credential subjects only (not in code) | |

### 3.2 IDs you get after creating objects

| Value | Lab 1 value | Files | When you know it |
|---|---|---|---|
| `bg-ca-exclusion` group object ID | `21008cb0-56d6-4fc4-9f1c-9e20dc1d5620` | `entra/legacy/locals.tf`, `entra/waves/wave-00/data.tf`, `entra/waves/wave-01/data.tf`, **`policy/ca-break-glass.rego`**, **`policy/fixtures/pass-plan.json`** | After creating the break-glass group |
| Owner account object ID (excluded from CA) | `b4a88d50-ea8b-48e2-8853-7e4bd1c1c841` | `entra/legacy/locals.tf`, `entra/waves/wave-00/data.tf`, `entra/waves/wave-01/data.tf` | After sign-up: `az ad signed-in-user show --query id -o tsv` |
| `iac-lab-admin` object ID | `1028c48b-19bd-4852-85a4-2cd92e274b06` | `entra/legacy/groups.tf` (brownfield group member) | After creating the admin |
| Okta built-in default authentication policy ID | `rst188pzg3iEP5uGh698` | `okta-inventory/groups.tf` (`default_app_signon_policy_id`) | After the seed; read it from the Admin Console or the API |
| Okta object IDs (29 import blocks) | `00g...`, `0oa...`, `rst...` | `okta-inventory/imports.tf`, IDs inside `okta-inventory/*.tf` | After the seed (regenerate, section 6) |
| Entra brownfield object IDs (9 import blocks) | various | `entra/legacy/imports.tf`, `entra/legacy/*.tf` | After building the brownfield objects (regenerate, section 6) |
| wave-01 move: wave-00 object IDs (15 import blocks per copy) | various | `entra/waves/wave-01/imports.tf`, `entra/waves/wave-00/moves.tf` | Do not port. Both files only moved apps that already existed between state files, and were deleted by PR #16 after the move. In a new build, write each app in its wave folder from the start |
| Pipeline app client IDs | `iac-reader`, `iac-planner`, `iac-applier` appIds | GitHub variables only: `READER_CLIENT_ID`, `PLANNER_CLIENT_ID`, `APPLIER_CLIENT_ID`, and `AZURE_CLIENT_ID` (environment `okta-read`) | After creating the app registrations |

**Do not change:** `non_gallery_template_id` (`8adf8e6e-...`), the SAML `User` role ID (`18d14569-...`), the Zoom gallery template and role IDs in `entra/legacy/app-zoom.tf`, and the all-zeros default access role. These are Microsoft-wide constants, the same in every tenant.

### 3.3 Test targets (change only if you use other testers)
| Value | Files |
|---|---|
| SAML test site `https://sptest.iamshowcase.com/acs`, audience `IAMShowcase` | `okta-inventory/seed/seed-okta-org.sh`, `okta-inventory/app-iac-saml-*.tf`, `entra/waves/wave-00/apps-saml.tf`, `entra/waves/wave-00/data.tf`, `entra/waves/wave-01/app-*.tf`, `entra/waves/wave-01/data.tf` |
| OIDC tester `https://oidcdebugger.com/debug` | `okta-inventory/seed/seed-okta-org.sh`, `okta-inventory/app-iac-oidc-portal.tf`, `entra/waves/wave-00/app-oidc.tf` |

### 3.4 Docs that name lab 1
`README.md` (status, adapting table, examples), `CLAUDE.md` (lab accounts, the owner's company tenant rule), `docs/lab-naming.md`, `docs/run-1-scope.md` facts table, `docs/git-check-plans-info.md` (`gh api` paths), `docs/migration-runbook.md` (run notes). Update the names; keep the method text.

## 4. Federated credential subjects

This repo uses GitHub's immutable subject format (`use_immutable_subject: true`), which carries numeric IDs. Check the new repo with the `customization/sub` call in section 2, then build each subject:

```
repo:<org>@<org-id>/<repo>@<repo-id>:<suffix>
```

| App registration | Credential name | Suffix |
|---|---|---|
| `iac-reader` | `github-okta-read` | `environment:okta-read` |
| `iac-reader` | `github-main` | `ref:refs/heads/main` |
| `iac-planner` | `github-pull-request` | `pull_request` |
| `iac-applier` | `github-env-nonprod` | `environment:nonprod` |
| `iac-applier` | `github-env-prod` | `environment:prod` |

A names-only subject (`repo:<org>/<repo>:...`) fails with `AADSTS700213`.

## 5. Find anything you missed

After replacing, this must print nothing (run from the repo root in the Ubuntu terminal):

```bash
git grep -n -E "integrator-2631921|0oa18siafpuScaofm698|bed5d4c3-98f0|6ea51c80-90de|stiaclabtfstate02|21008cb0-56d6|b4a88d50-ea8b|1028c48b-19bd|rst188pzg3iEP5uGh698|336396784|1399352055|lamigrationlaboutlook|la-migration-lab|iac-migration-lab/okta-to-entra" -- ':!docs/archive'
```

Then run the checks:

```bash
source lab-tools/env.sh
terraform fmt -recursive -check
policy/test.sh   # must end "policy self-test OK" (it uses the new bg-ca-exclusion ID)
git ls-files --eol | grep -c 'w/crlf'   # must print 0: no Windows line endings crept in while editing
```

## 6. Rebuild order

State is rebuilt, never copied. Follow [build-by-hand.md](build-by-hand.md) in order. The porting-specific points:

1. **Accounts, WSL2 and tools** (build-by-hand parts 1 and 2). Check the Okta org is Identity Engine before anything else.
2. **Seed Okta**, then **regenerate the Okta inventory:** replace every `id` in `okta-inventory/imports.tf` with the new org's IDs (the build-by-hand guide lists the API calls), set `default_app_signon_policy_id`, run `terraform plan -generate-config-out=generated.tf` only for objects whose settings differ, and plan until "No changes".
3. **Azure state storage and `iac-reader`**, then move the Okta state into the new storage account.
4. **Entra brownfield:** build the legacy objects by hand, then replace the IDs in `entra/legacy/imports.tf` and the `locals.tf` values. Plan until "No changes".
5. **Pipeline identities, GitHub settings, then platform and wave-00 through the first PR.** Create each new state file once with your own login before the first PR (the planner cannot create state files).
6. **Tests:** sign-ins, the three exit-test PRs, drift.

## 7. Porting checklist

- [ ] WSL2 Ubuntu 24.04 set up; repo and `~/.okta-lab/` inside the Ubuntu home folder
- [ ] New Okta org is Identity Engine (`"pipeline": "idx"`)
- [ ] Repo copied; old records archived; new findings log and permission register started
- [ ] New public repo in a GitHub org; org ID, repo ID and subject format recorded
- [ ] Section 3.1 values replaced
- [ ] Okta seeded; `okta-inventory` IDs regenerated; plan "No changes"
- [ ] Storage account created; all state keys bootstrapped; `okta-inventory` state migrated
- [ ] Break-glass group created; its ID in the four files of section 3.2; `policy/test.sh` passes
- [ ] Entra brownfield built and imported; plan "No changes"
- [ ] Pipeline identities, federated credentials (section 4), Graph permissions, storage roles
- [ ] GitHub environments, variables, secret, labels, branch protection
- [ ] Section 5 search prints nothing
- [ ] First PR plans green; merge applies nonprod and prod
- [ ] Every grant written in the new permission register

## 8. Making the next port easier (run 2 ideas)
- Move the storage account name out of every `backend.tf` into `-backend-config` (the pipeline already passes the container that way).
- Read `org_name` and `client_id` for Okta from environment variables (`OKTA_ORG_NAME`, `OKTA_API_CLIENT_ID`; UNVERIFIED for okta provider 7.0.0) and `OKTA_ORG_URL` in `snapshot.yml` from a GitHub variable.
- Put the break-glass group ID and owner ID in `tenants/*.tfvars`, and pass the group ID to Conftest as data instead of hard-coding it in `policy/ca-break-glass.rego`.
