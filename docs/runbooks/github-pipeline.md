# GitHub and Pipeline Engineer Runbook

## Your role

You own the **pipeline**: the GitHub repository settings, workflows and scripts that move every change from a pull request to Entra, and that watch Okta and Entra every night. You keep the gates working (required checks, change gate, policy checks, prod approval) and you keep the pipeline's sign-in to Azure working without secrets.

You do not decide what changes in Okta or Entra; the platform engineers do. You make sure their changes can only arrive the controlled way.

## What you own

| Item | Where |
|---|---|
| Workflows `plan`, `apply`, `drift`, `snapshot`, `change-gate` | [.github/workflows/](../../.github/workflows/) |
| Scripts `tf-roots.sh`, `change-gate.sh`, `install-conftest.sh` | [.github/scripts/](../../.github/scripts/) |
| Pull request template | [.github/pull_request_template.md](../../.github/pull_request_template.md) |
| Branch protection on `main` (four required checks) | Settings → Branches |
| Environments `okta-read`, `nonprod`, `prod` (reviewers, branch policy, secrets) | Settings → Environments |
| Repository variables, environment variables and secrets | Settings → Secrets and variables → Actions |
| Labels for the change gate and drift | Issues → Labels |
| Federated credentials on `iac-reader`, `iac-planner`, `iac-applier` (with the Azure engineer) | Entra → App registrations → Certificates & secrets → Federated credentials |
| Tool and action versions (Terraform 1.16.4, Conftest 0.71.0, actions pinned to commit SHAs) | Workflows, [../tool-install.md](../tool-install.md) |

Full description of each workflow and setting: [.github/pipeline-guide.md](../../.github/pipeline-guide.md).

## Access you need

| Access | Production target | Lab today |
|---|---|---|
| GitHub | Repository admin (settings), not a required reviewer on `prod` | Owner (org owner) |
| Entra | Application Administrator, to manage federated credentials on the three pipeline apps | Owner |

## Daily checks (5 minutes)
1. **Actions** tab: last night's **snapshot** and **drift** ran (scheduled 09:17 and 10:41 UTC (Coordinated Universal Time); GitHub often starts them hours late). A job that did not run at all is yours; a red result inside the Terraform step belongs to the Okta or Entra engineer.
2. Any **apply** run waiting for approval for more than a day: remind the reviewer, or cancel it if the change was abandoned.

## Monthly
- **Settings check** against the expected values:
  ```bash
  R=<org>/<repo>
  gh api repos/$R/branches/main/protection --jq '{checks: .required_status_checks.contexts, strict: .required_status_checks.strict, reviews: .required_pull_request_reviews.required_approving_review_count}'
  gh api repos/$R/environments/prod --jq '{reviewers: [.protection_rules[] | select(.type=="required_reviewers") | .reviewers[].reviewer.login], branch_policy: .deployment_branch_policy}'
  gh api repos/$R/environments/okta-read/secrets --jq '.secrets[] | "\(.name) updated \(.updated_at)"'
  gh api repos/$R/actions/oidc/customization/sub
  ```
  Expected: checks `policy-selftest`, `change-gate / check`, `plan (lab-np)`, `plan (lab)`; strict true; a reviewer on `prod`; deployments from `main` only; `use_immutable_subject: true`.
- **Action and tool updates:** check for new releases of the pinned actions and tools. Update one at a time by pull request, with the commit SHA and the version in a comment.

## Change gate failures
Status: Run 1. The `change-gate / check` job fails with a message that says why:

| Message | Fix |
|---|---|
| "has no 'Change: <system>:<id>' line" | Edit the pull request description: first line `Change: github:<issue number>` |
| "is not labeled 'change'" / "needs exactly one change:<state> label" | Fix the issue's labels: `change` plus one of `change:scheduled` or `change:implement` |
| "is 'draft'; needs scheduled or implement" | The change is not approved yet; the change manager moves it on |
| "no window_start / window_end" / "outside the window" | Add or correct the window lines in the issue body (UTC, ISO 8601, e.g. `2026-11-01T00:00:00Z`) |
| "commit … has no pull request" (in `apply`) | Someone pushed to `main` directly with a change under `entra/` or `policy/`. Nothing was applied. Redo it through a pull request |

After fixing the issue, re-run the failed job (it reads the issue again).

## Federated credential errors
Status: Run 1. `AADSTS700213: No matching federated identity record found for presented assertion subject '...'` means the subject in Entra does not match what GitHub sends.
1. Copy the subject from the error message.
2. Compare with the app's federated credentials:
   ```bash
   az ad app federated-credential list --id <appId> --query "[].[name,subject]" -o tsv
   ```
3. This repo uses GitHub's immutable subject format: `repo:<org>@<org id>/<repo>@<repo id>:<suffix>`. Suffixes: `environment:okta-read` and `ref:refs/heads/main` (reader), `pull_request` (planner), `environment:nonprod` and `environment:prod` (applier).
4. Fix it with `az ad app federated-credential update --id <appId> --federated-credential-id <name> --parameters <json>` (or delete and re-create), and register the change.

## Renaming a job, a workflow or an environment
- Renaming a job or its matrix values renames the required check. Branch protection then waits forever for the old name. Update the protection rule in the same change ([../git-check-plans-info.md](../git-check-plans-info.md) has the command).
- Renaming an environment changes the federated subject. Add the new credential before the rename, remove the old one after.

## Add a new pipeline secret or variable
1. Put it at the narrowest level: environment over repository.
2. `gh secret set <NAME> --env <environment>` (value from a file or stdin, never on the command line).
3. Register it in the permission register. Note its owner and rotation date.

## Pipeline down: no runs starting
1. Check https://www.githubstatus.com for Actions incidents.
2. Check that Actions is enabled for the repo and the workflows are not disabled (`gh workflow list --all`). GitHub disables scheduled workflows after 60 days with no repository activity.
3. Check the organization's Actions minutes (free for public repositories).

## Emergency: a change must reach Entra now
The pipeline is the only route. Fastest controlled path: change ticket with `change:implement` and a window covering now, pull request, checks (about 3 minutes), merge, approve prod. If the pipeline itself is broken and Entra access is at risk, the Entra engineer uses break-glass in the portal and codifies the change by pull request the next working day. Do not turn off branch protection to push directly.

## Do not
- Do not upload plan files or state as artifacts: the repo is public and plans can contain sensitive values.
- Do not add client secrets to the pipeline apps. Federated credentials only.
- Do not protect the `inventory-counts` branch (the snapshot writes counts there).
- Do not make the repository private on the free plan: required reviewers, environment secrets and branch protection stop working.

## Lab 1 lessons
- Read the subject format (`gh api repos/<repo>/actions/oidc/customization/sub`) before creating any federated credential.
- `prevent_self_review` must be off when one person is both author and reviewer, or there is nothing to tick in the approval dialog.
- Direct admin pushes that touch `entra/**` start `apply.yml`, which the change gate stops. Markdown-only changes are ignored.
