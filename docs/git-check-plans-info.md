# Git Check Plans: What Each Required Check Does

Plain-language guide to the four checks that must pass before a pull request (PR) can merge into `main`, and the GitHub API (application programming interface) commands that set and verify branch protection.

Source files: `.github/workflows/plan.yml`, `.github/workflows/change-gate.yml`, `.github/scripts/tf-roots.sh`, `.github/scripts/change-gate.sh`, `policy/test.sh`. Design of the gate: `docs/change-gate-design.md`.

## When the checks run
- Every PR that targets `main` starts the `plan` workflow. Pushing a new commit to the PR cancels the old run and starts a new one.
- Nothing in these checks changes Entra. They only read and report. Changes happen later, in `apply.yml`, after the PR merges.

## The four required checks

| Check name (as GitHub shows it) | What it asks | Signs in as | Fails when |
|---|---|---|---|
| `policy-selftest` | Do the policy rules themselves still work? | Nobody (no cloud access) | A rule stops catching a known-bad example, or blocks a known-good one |
| `change-gate / check` | Is there an approved change record, and are we inside its window? | GitHub's built-in token (read issues and PRs only) | No change line in the PR, wrong state, or outside the window |
| `plan (lab-np)` | What would this PR change in the nonprod copy, and does it break policy? | `iac-planner` (read-only, no secret) | Terraform errors, formatting is off, or a policy rule fails |
| `plan (lab)` | Same question for prod | `iac-planner` | Same as above |

### 1. `policy-selftest`
- **What it is:** a test of the tests. The policy rules (Conftest, written in Rego, the OPA (Open Policy Agent) language) live in `policy/`.
- **How it works:** `policy/test.sh` feeds two sample plans to the rules:
  - `fixtures/pass-plan.json` must pass.
  - `fixtures/fail-plan.json` must fail all three rules:
    - Every Conditional Access (CA) policy must exclude the break-glass group (`bg-ca-exclusion`).
    - A new CA policy must start in report-only mode.
    - Nothing in `entra/legacy` may be destroyed.
- **Why it matters:** if someone edits a rule and breaks it, real plans would pass silently. This check catches that before any plan runs. The two `plan` checks wait for it.

### 2. `change-gate / check`
- **What it is:** the stand-in for a change ticket in an ITSM (IT Service Management) tool such as ServiceNow. In the lab, a GitHub Issue is the change record.
- **How it works:**
  1. Reads the PR description for a line `Change: github:<issue number>` (PR #2 uses `Change: github:1`).
  2. Opens that issue and checks:
     - It has the label `change`.
     - It has exactly one state label, and it is `change:scheduled` or `change:implement`.
     - The current time (UTC (Coordinated Universal Time)) is between the `window_start:` and `window_end:` lines in the issue body.
- **Why it matters:** no change reaches Entra without an approved, time-boxed change record. `apply.yml` runs the same gate again after merge, so **merging after the window closes means the apply fails.**
- **To fix a failure:** edit the issue (state label, or extend the `window_end:` line), then re-run the check from the PR's Checks tab.

### 3 and 4. `plan (lab-np)` and `plan (lab)`
- **What it is:** one job run twice, once per environment (a "matrix"):
  - `lab-np` = the nonprod copy: same tenant, names prefixed `iac-np` and `LAB-NP`, state in the `tfstate-nonprod` container.
  - `lab` = prod: names prefixed `iac` and `LAB`, state in the `tfstate-prod` container.
- **How it works** (`.github/scripts/tf-roots.sh plan <env>`):
  1. `terraform fmt -check`: fails if any `.tf` file is not formatted.
  2. For each Entra root that has a `tenants/<env>.tfvars` file, in order `entra/legacy` (prod only), `entra/platform`, then each `entra/waves/*`:
     - `terraform init` against that environment's state (no lock, because the read-only planner cannot take a lease).
     - `terraform validate`: syntax and references.
     - `terraform plan`: compares the code with what is really in Entra.
     - `conftest test`: runs the policy rules against the plan.
  3. Writes a table to the run's Summary page: root, plan result ("No changes" or "N to add..."), Conftest pass/fail, result.
- **The "skipped" result:** if `entra/platform` has things still to create (as nonprod does before its first apply), a wave root that looks up those objects cannot plan yet. It is marked ⏭️ skipped instead of failed. After the platform apply, the wave plans normally.
- **What "green" means:** the code is valid, the plan ran, and no policy rule was broken. It does not mean "no changes"; read the Summary table to see what would change.
- **Plan files are not uploaded:** the repo is public, and anyone could download workflow artifacts. Conftest runs inside the same job instead.

## Related workflows (not required checks)
- **`apply.yml`:** runs on merge to `main`. Change gate again, then plan, Conftest, and apply, nonprod first and then prod. Signs in as `iac-applier`. Prod waits for a reviewer approval on the `prod` environment.
- **`drift.yml`:** nightly, from `main`. Plans every root as `iac-reader` and opens a `drift` issue if Entra no longer matches the code.
- **`snapshot.yml`:** nightly Okta inventory snapshot (Lab Phase 1).

## Branch protection by command
Run these from a terminal signed in to `gh` as the repo owner. Two reasons to use them: to set protection without clicking through the web page, or to rebuild it in a later run.

**Set or replace protection on `main`:**
```bash
gh api -X PUT repos/iac-migration-lab/okta-to-entra-migration-factory/branches/main/protection \
  --input - <<'EOF'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["policy-selftest", "change-gate / check", "plan (lab-np)", "plan (lab)"]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": { "required_approving_review_count": 0 },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF
```
- `strict: true` = the PR branch must be up to date with `main` before merging.
- `enforce_admins: false` = the owner can still push doc-only commits straight to `main` (accepted lab risk; production should set `true`).
- `required_approving_review_count: 0` = a PR is required but no approval, because the lab has one person and GitHub blocks approving your own PR. Production should require at least 1.

**Verify:**
```bash
gh api repos/iac-migration-lab/okta-to-entra-migration-factory/branches/main/protection \
  --jq '{checks: .required_status_checks.contexts, strict: .required_status_checks.strict, admins_enforced: .enforce_admins.enabled}'
```
"Branch not protected" (HTTP 404) means no rule exists.

**Remove (only to reset the lab):**
```bash
gh api -X DELETE repos/iac-migration-lab/okta-to-entra-migration-factory/branches/main/protection
```

**Web path (same result):** repo page > **Settings** > left sidebar under **Code, planning, and automation** > **Branches** > **Add classic branch protection rule**. Under **Require a pull request before merging**, untick **Require approvals**. Leaving it at 1 blocks every merge in a one-person lab (run 1 hit this on PR #2).

## Approving the prod deployment
- After a merge, `apply.yml` stops before `prod` and the run page shows a yellow banner: "prod require an approval". Click **View**, tick **prod**, then click **Approve and deploy**.
- If the window shows "Review needed" with no tick box, **Prevent self-review** is on. GitHub hides the approval from whoever triggered the run, and in the lab that is always the owner. Fix: **Settings** > **Environments** > **prod** > untick **Prevent self-review** > **Save protection rules**. The pending run picks up the change; there's no need to restart it.
- Check the environment setting:
  ```bash
  gh api repos/iac-migration-lab/okta-to-entra-migration-factory/environments/prod \
    --jq '.protection_rules[] | select(.type=="required_reviewers") | {prevent_self_review, reviewers: [.reviewers[].reviewer.login]}'
  ```
- Production: two named reviewers, self-review on. Do not create a second GitHub account to review your own work; GitHub's terms allow one free personal account per person.

## If you rename a job
Required check names are plain text. If a job in `plan.yml` or `change-gate.yml` is renamed, the old name stays required and every PR waits forever for it ("Expected — Waiting for status to be reported"). Update the protection rule with the new name in the same PR.
