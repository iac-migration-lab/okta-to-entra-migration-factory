# Pipeline Guide (.github)

## What this folder is for

(This guide is not named README.md because GitHub would show a `.github/README.md` on the repo front page in place of the main README.)

This is the CI/CD (continuous integration and continuous delivery) pipeline: the GitHub Actions workflows and scripts that check, apply and watch every change. It is what turns "identity as code" from files in a folder into a controlled process:
- Nobody changes Entra by hand. A change is a pull request; the pipeline plans it, checks it against policy and a change ticket, and applies it after merge and approval.
- Every night, the pipeline compares Okta and Entra with the code and raises the alarm when they differ.

## The workflows

| Workflow | Runs when | Signs in as | What it does |
|---|---|---|---|
| [workflows/plan.yml](workflows/plan.yml) | Every pull request to `main` | `iac-planner` (read-only) | Policy self-test; change gate; `terraform fmt` check; plan and Conftest for every Entra root, once for nonprod (`lab-np`) and once for prod (`lab`). Changes nothing |
| [workflows/apply.yml](workflows/apply.yml) | A merge to `main` that touches `entra/**` or `policy/**`; or by hand | `iac-applier` | Change gate again; applies **nonprod**; then waits for a person to approve the `prod` environment; applies **prod**. After each apply, re-plans and requires "No changes" |
| [workflows/drift.yml](workflows/drift.yml) | Nightly 10:41 UTC (Coordinated Universal Time); or by hand | `iac-reader` | Plans prod Entra. Any difference opens one issue labeled `drift` (or comments on the open one) and turns the run red. Never fixes anything itself |
| [workflows/snapshot.yml](workflows/snapshot.yml) | Nightly 09:17 UTC; or by hand | `iac-reader` (Azure) and `iac-okta-reader` (Okta) | Plans `okta-inventory/`; red if Okta changed. Uploads user and assignment JSON to Blob; commits object counts to the branch `inventory-counts` |
| [workflows/change-gate.yml](workflows/change-gate.yml) | Called by `plan.yml` and `apply.yml` | No cloud sign-in | Fails unless the pull request points at an approved change ticket whose time window includes now |

GitHub often starts scheduled runs late (in lab 1, by about 5 hours). That is normal for the free scheduler.

## The scripts

| Script | What it does |
|---|---|
| [scripts/tf-roots.sh](scripts/tf-roots.sh) | The engine of `plan.yml`, `apply.yml` and `drift.yml`. Usage: `tf-roots.sh plan\|apply\|drift <lab\|lab-np>`. Finds every Entra root that has `tenants/<tenant_key>.tfvars`, in order (`legacy`, `platform`, `waves/*`); points it at the right state container; runs init, validate, plan and Conftest; in apply mode applies the saved plan. Writes a table to the run summary |
| [scripts/change-gate.sh](scripts/change-gate.sh) | Reads the `Change: <system>:<id>` line from the pull request, fetches the ticket through an adapter, and checks its state and window. The lab adapter reads GitHub Issues; a ServiceNow or Jira adapter would be another function in this script ([docs/change-gate-design.md](../docs/change-gate-design.md)) |
| [scripts/install-conftest.sh](scripts/install-conftest.sh) | Installs Conftest 0.71.0 on the runner, after checking its checksum |
| [pull_request_template.md](pull_request_template.md) | Pre-fills every pull request with the `Change: github:` line the gate reads |

### Details of `tf-roots.sh` worth knowing
- **Replication retries.** Entra can take a few seconds to show a new object everywhere. In apply mode, a failed plan or apply is retried once after 30 seconds.
- **Post-apply check.** After applying, the root is planned again and must show no changes. One more policy-checked apply is allowed (needed for fresh SAML apps); if it still is not clean, the job fails.
- **Skipped waves on a first build.** In plan mode, if `platform` has pending creates, a wave plan that fails because those objects do not exist yet is shown as "skipped", not failed.
- **No plan files are uploaded.** A plan can hold sensitive values, and artifacts on a public repo are downloadable by anyone.

## Required checks and approvals

Branch protection on `main` requires four checks to pass before a merge: `policy-selftest`, `change-gate / check`, `plan (lab-np)`, `plan (lab)`. A pull request is required, with 0 approvals (the lab has one person, who cannot approve their own pull request). The `prod` environment requires a named reviewer to click **Approve and deploy**. Details and the exact `gh api` command: [docs/git-check-plans-info.md](../docs/git-check-plans-info.md).

**Renaming a job or the matrix values renames its check.** Branch protection would then wait forever for the old name. Update the protection rule in the same change.

## Settings the workflows depend on (not in files)

| Setting | Where | Values |
|---|---|---|
| Repository variables | Settings → Secrets and variables → Actions → Variables | `AZURE_TENANT_ID`, `PLANNER_CLIENT_ID`, `APPLIER_CLIENT_ID`, `READER_CLIENT_ID` |
| Environment `okta-read` | Settings → Environments | Variables `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `OKTA_CLIENT_ID`, `OKTA_KEY_ID`; secret `OKTA_PRIVATE_KEY` |
| Environment `nonprod` | Settings → Environments | No reviewer |
| Environment `prod` | Settings → Environments | Required reviewer; deployments from `main` only |
| Labels | Issues → Labels | `change`, `change:draft`, `change:assess`, `change:scheduled`, `change:implement`, `change:closed`, `change:cancelled`, `drift` |
| Federated credentials | On each Entra app registration | One per workflow trigger; subjects use GitHub's ID-based format `repo:<org>@<org id>/<repo>@<repo id>:<suffix>` |

No client secrets exist for any pipeline identity: each run gets a short-lived token from GitHub that Entra trusts.

## Making a change through the pipeline

1. Open an issue with labels `change` and `change:scheduled`, and in the body:
   ```
   window_start: 2026-11-01T00:00:00Z
   window_end: 2026-11-03T00:00:00Z
   ```
2. Make the change on a branch, open a pull request, and set the first line to `Change: github:<issue number>`.
3. Wait for the four checks. Read the plan tables in each run summary.
4. Merge. Open Actions → **apply** → the new run. Nonprod applies on its own; for prod, click **Review deployments**, tick `prod`, **Approve and deploy**.
5. Close the issue and set its label to `change:closed`.

## Read next
- [docs/git-check-plans-info.md](../docs/git-check-plans-info.md): each required check in detail.
- [docs/change-gate-design.md](../docs/change-gate-design.md): how the gate would plug into a real ticket system.
