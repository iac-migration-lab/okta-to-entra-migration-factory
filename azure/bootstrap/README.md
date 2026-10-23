# Azure Bootstrap: What the Pipeline Stands On

## What this folder is for

The pipeline needs some Azure pieces to exist before it can run at all, most importantly the storage account that holds every Terraform state file. Those pieces cannot be managed by the pipeline itself: a pipeline that could change its own state storage could also delete it. So they live here, in a separate Terraform root that **only the owner applies, from a laptop, with their own Azure CLI (command-line interface) login**.

The pipeline identities (`iac-reader`, `iac-planner`, `iac-applier`) hold no roles on the Azure subscription, only data roles on single storage containers. They could not apply this folder even by mistake.

## What is in it

| File | What it holds |
|---|---|
| `budget.tf` | `budget-iac-lab-monthly`: $10 a month on the lab subscription, email alerts at 50%, 80% and 100% of actual spend. Built by hand on 2026-10-01, imported on 2026-10-18 (the `import` block is in the same file) |
| `providers.tf` | `azurerm` provider pinned to the lab subscription. `resource_provider_registrations = "none"`, so Terraform does not try to register Azure services on its own |
| `versions.tf` | Terraform 1.16.4, `hashicorp/azurerm` 4.81.0 |
| `backend.tf` | State `tfstate-prod/azure/bootstrap/terraform.tfstate` |

## Built by hand, not yet in this folder

These exist and work, but were created with `az` commands in Lab Phase 1 ([docs/build-by-hand.md](../../docs/build-by-hand.md) part 6). Importing them here is a run 2 task.

| Object | Settings |
|---|---|
| Resource group `rg-iac-lab` | West US 3 |
| Storage account `stiaclabtfstate02` | Standard LRS (locally redundant storage); storage account keys off (Entra ID sign-in only); no public blob access; TLS (Transport Layer Security) 1.2 minimum; blob versioning on; 7-day soft delete for blobs and containers |
| Container `tfstate-prod` | State for `okta-inventory`, `azure/bootstrap`, and the prod copy of every Entra root |
| Container `tfstate-nonprod` | State for the nonprod copy of `entra/platform` and `entra/waves/*` |
| Container `okta-exports` | Nightly user and assignment JSON from the Okta snapshot (personal data, never in Git) |
| Role assignments | Per-container data roles for each pipeline identity; Storage Blob Data Contributor on the account for the owner. Listed in [docs/permission-register.md](../../docs/permission-register.md) |

**Chicken and egg:** this folder keeps its own state in the storage account it will one day manage. That works because the account is created first by hand, then imported. Never let a plan here delete or replace the storage account; add `prevent_destroy` when you import it.

## Run it

```bash
source lab-tools/env.sh
az login --tenant <lab tenant ID>       # browser sign-in; security defaults may block the device code flow
terraform -chdir=azure/bootstrap init
terraform -chdir=azure/bootstrap plan    # expect: No changes
```
Apply only after reading the plan, and add a findings log entry: this root is outside the pipeline on purpose, so the log is its audit trail.

## Read next
- [../../entra/README.md](../../entra/README.md): which state file holds what.
- [docs/build-by-hand.md](../../docs/build-by-hand.md) part 6: building the storage from nothing.
