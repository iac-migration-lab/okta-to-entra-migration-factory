# Entra: the Target, Written as Code

Everything in this folder describes Microsoft Entra ID (the target identity platform) in Terraform. Terraform reads these files, compares them with the live tenant, and shows or makes the difference. The pipeline in `.github/workflows/` is the only thing that applies changes here from Lab Phase 3 on.

## Why three folders (three "roots")

A Terraform **root** is a folder Terraform runs in, with its own state file. Each Entra root has a different job and a different risk level, so each is planned, policy-checked and applied on its own.

| Root | Holds | Who made the objects | Risk if wrong | Applied by |
|---|---|---|---|---|
| [legacy/](legacy/) | Objects that already existed before the migration (the "brownfield") | A person, by hand in the portal | High: these are live, in-use policies | Import only; never changed by the migration |
| [platform/](platform/) | Shared building blocks that every wave needs (staff groups, named locations) | Terraform | Medium: many apps depend on them | Pipeline |
| [waves/](waves/) | The migrated apps, one folder per batch ("wave") | Terraform | Contained to one wave | Pipeline |

Order matters: **platform before waves**. Wave code looks up the staff groups by name, so the groups must exist first. The pipeline script `.github/scripts/tf-roots.sh` always runs `legacy`, then `platform`, then each `waves/*` folder.

## Two copies in one tenant: prod and nonprod

The free lab has a single Entra tenant, so "nonprod" is a prefixed copy inside it. A variable file per copy picks the names; the state container keeps their records apart.

| `tenant_key` | Var file | Names | CA (Conditional Access) names | State container |
|---|---|---|---|---|
| `lab` (prod) | `tenants/lab.tfvars` | `iac-*` | `LAB-CA*` | `tfstate-prod` |
| `lab-np` (nonprod) | `tenants/lab-np.tfvars` | `iac-np-*` | `LAB-NP-CA*` | `tfstate-nonprod` |

- A root takes part in a copy only if it has that `tenants/<tenant_key>.tfvars` file. `legacy/` has `lab.tfvars` only: there is one brownfield, and it is prod.
- On merge, nonprod applies first; prod applies only after a person approves the `prod` environment in GitHub.
- A real client would use two tenants. Then `lab-np.tfvars` becomes a file with the other tenant's ID, and nothing else changes.

## Where state lives

Azure Storage account `stiaclabtfstate02` (see [azure/bootstrap/](../azure/bootstrap/)). Sign-in is Entra ID only; storage account keys are turned off.

| Root | State key (blob name) |
|---|---|
| legacy | `entra/legacy/terraform.tfstate` (prod container only) |
| platform | `entra/platform/terraform.tfstate` |
| waves/wave-00 | `entra/waves/wave-00/terraform.tfstate` |

Each `backend.tf` names `tfstate-prod`. The pipeline swaps in `tfstate-nonprod` for the nonprod copy with `-backend-config=container_name=...`.

## Who signs in

No passwords or client secrets. GitHub Actions proves who it is to Entra with a short-lived token (a federated credential), and each job gets a different identity:

| Identity | Used by | Can do |
|---|---|---|
| `iac-planner` | `plan.yml` on every pull request | Read Entra; read state |
| `iac-applier` | `apply.yml` after merge (`nonprod` and `prod` environments) | Write apps, groups, CA policies, claims; write state |
| `iac-reader` | `drift.yml` nightly; local plans of `legacy/` | Read Entra; write `tfstate-prod` (needed by the snapshot) |

Every grant is listed in [docs/permission-register.md](../docs/permission-register.md).

## Guard rails on every plan

Conftest (a policy test tool) runs three rules from [policy/](../policy/) against every plan, and the pipeline refuses to apply a plan that breaks one:
1. Every CA policy excludes the break-glass group `bg-ca-exclusion`, so nobody locks the admins out.
2. Every new CA policy starts in report-only mode (it logs what it would do, and blocks nothing).
3. Nothing in `legacy/` is ever destroyed.

## Versions

Terraform 1.16.4; `hashicorp/azuread` 3.10.0; `microsoft/msgraph` 0.5.0 (preview; `waves/` only). Pinned exactly in each `versions.tf`. The lock file `.terraform.lock.hcl` is git-ignored, so the exact pin is what keeps runs repeatable.

## Read next
- [docs/build-by-hand.md](../docs/build-by-hand.md) parts 8 to 12: building these roots from nothing.
- [docs/git-check-plans-info.md](../docs/git-check-plans-info.md): the checks every pull request must pass.
- [docs/migration-runbook.md](../docs/migration-runbook.md): how a wave moves apps from Okta to Entra.
