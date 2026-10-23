# Policy: Rules Every Change Must Pass

## What this folder is for

Automatic guard rails. Before the pipeline applies any Entra change, it checks the Terraform plan against the rules in this folder. A plan that breaks a rule fails the pull request check, cannot be merged, and is never applied. This catches dangerous mistakes that a tired reviewer could miss, every time, the same way.

The rules are written in **Rego**, the language of OPA (Open Policy Agent), and run by **Conftest**, a tool that tests structured files (here, a plan exported as JSON (JavaScript Object Notation)) against Rego rules. Conftest version 0.71.0, pinned and checksum-verified by `.github/scripts/install-conftest.sh`.

## The three rules

| File | Rule | Why it exists |
|---|---|---|
| `ca-break-glass.rego` | Every CA (Conditional Access) policy a plan **creates or updates** must list the group `bg-ca-exclusion` in its excluded groups | Break-glass accounts are the emergency way into the tenant. A CA policy that catches them can lock every admin out |
| `ca-report-only.rego` | Every **new** CA policy must start in report-only mode (`enabledForReportingButNotEnforced`) | A new policy should first show, in the sign-in logs, whom it would block. Turning it on is a second, reviewed change |
| `legacy-no-destroy.rego` | No resource in `entra/legacy/` may be **deleted** | The brownfield objects are live and in use. This backs up `prevent_destroy` in the code |

Each rule produces a plain message naming the resource, for example: `azuread_conditional_access_policy.lab_ca10: CA policy must exclude bg-ca-exclusion (21008cb0-...)`.

## Other files

| File | What it is |
|---|---|
| `test.sh` | Self-test. The pass fixture must pass; the fail fixture must trip all three rules. The `policy-selftest` check runs it on every pull request, so a broken rule cannot silently pass everything |
| `fixtures/pass-plan.json` | A tiny fake plan that follows every rule |
| `fixtures/fail-plan.json` | A tiny fake plan that breaks every rule (a new, enabled CA policy with no exclusion; a delete) |
| `fixtures/legacy-context.json` | Tells the no-destroy rule which folder the plan came from (`entra/legacy`) |

## How the pipeline uses it

`.github/scripts/tf-roots.sh` runs for each Entra root, in `plan.yml`, `apply.yml` and `drift.yml`:
1. `terraform plan -out=<file>`, then `terraform show -json` turns the plan into JSON.
2. It writes a small context file, `{"context": {"root": "<folder>", "tenant_key": "<lab or lab-np>"}}`, so rules can tell which folder a plan came from.
3. `conftest test --policy policy/ --data <context> <plan.json>`.
4. Any failure: the check is red, the failures appear in the run summary, and in `apply.yml` that root is not applied.
5. After an apply, if a second apply is needed to reach a clean plan, that plan is checked again first.

Lab 1 proved it: PR #4 removed the break-glass exclusion on purpose, and both plan checks failed with the message above (2026-10-20).

## Run it yourself

```bash
source lab-tools/env.sh
policy/test.sh                                                     # self-test

# One real plan:
terraform -chdir=entra/waves/wave-00 plan -var-file=tenants/lab.tfvars -out=/tmp/w0.tfplan
terraform -chdir=entra/waves/wave-00 show -json /tmp/w0.tfplan > /tmp/w0.json
echo '{"context":{"root":"entra/waves/wave-00","tenant_key":"lab"}}' > /tmp/ctx.json
conftest test --policy policy/ --data /tmp/ctx.json /tmp/w0.json
```

## Changing or adding a rule

1. Write the rule in a new `.rego` file with `package main` and a `deny contains msg if { ... }` block. Read the plan through `input.resource_changes`.
2. Add a case to `fixtures/fail-plan.json` that the rule must catch, and make sure `fixtures/pass-plan.json` still passes.
3. Add the expected message to the list in `test.sh`.
4. Run `policy/test.sh`, then open a pull request. A change in `policy/` also triggers `apply.yml` after merge, so the new rule is checked against live plans straight away.

**When porting to a new tenant:** the break-glass group ID is written in `ca-break-glass.rego` and `fixtures/pass-plan.json`. Change both ([docs/porting-guide.md](../docs/porting-guide.md)).

## Ideas for later runs
- A rule that CA policies may only be turned on (`enabled`) by a pull request that changes nothing else.
- A rule that every app has `app_role_assignment_required = true` (only assigned users can sign in).

## Read next
- [docs/git-check-plans-info.md](../docs/git-check-plans-info.md): where the policy check sits among the required checks.
