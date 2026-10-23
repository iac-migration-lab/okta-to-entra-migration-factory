# Entra Platform: Shared Building Blocks

## What this folder is for

The shared Entra objects that many migrated apps rely on, created new by Terraform (not imported). Think of it as the foundation that the waves build on: every wave assigns its apps to these groups and points its CA (Conditional Access) policies at these locations.

Each object here is a **translation of something in Okta**. The comment at the top of each file names its Okta source in [okta-inventory/](../../okta-inventory/).

## What is in it

| File | Objects | Okta source |
|---|---|---|
| `groups.tf` | Security groups `iac-it`, `iac-custserv`, `iac-finance` | Okta groups `IT`, `CustServ`, `Finance` ([okta-inventory/groups.tf](../../okta-inventory/groups.tf)) |
| `named-locations.tf` | Named location `iac-nl-okta-office`, `203.0.113.0/24`, trusted | Okta network zone `iac-zone-office` ([okta-inventory/network-zones.tf](../../okta-inventory/network-zones.tf)) |
| `outputs.tf` | `staff_group_object_ids` | Shown after apply, for checks |
| `variables.tf` | `tenant_key`, `tenant_id`, `name_prefix` | `name_prefix` picks the copy: `iac` (prod) or `iac-np` (nonprod) |
| `tenants/lab.tfvars`, `tenants/lab-np.tfvars` | One file per copy | Same tenant ID in both (one lab tenant) |
| `backend.tf` | State `entra/platform/terraform.tfstate` in `tfstate-prod` (the pipeline uses `tfstate-nonprod` for nonprod) | |
| `providers.tf`, `versions.tf` | `hashicorp/azuread` 3.10.0, Terraform 1.16.4 | |

## Design choices worth knowing

- **Terraform manages the groups, not their members.** `ignore_changes = [members]` tells Terraform to leave membership alone. Membership comes from provisioning: in production, HR (human resources) data through SailPoint; in lab 1, test users added by CLI (command-line interface). If Terraform managed members, every new hire would be a code change.
- **Two named locations for one network, on purpose.** The brownfield already has `iac-legacy-nl-office` with the same IP range ([../legacy/](../legacy/)). A real client tenant has duplicates like this. The migration creates its own and leaves the legacy one alone; cleanup is a later, separate decision.
- **Groups are found by name.** Waves look up `iac-it` and the others by display name, so renaming a group here breaks every wave. Rename only with a plan that covers the waves too.

## Who runs it, and how

- **Pipeline (from Lab Phase 3):** `plan.yml` plans both copies on every pull request; `apply.yml` applies nonprod, then prod after approval; `drift.yml` checks prod nightly.
- **Apply order:** platform first, then `entra/waves/*`. On a first build, the wave plan shows "skipped" until platform exists; that is expected.
- **Local plan of prod** (your Azure CLI login can read these objects):

```bash
source lab-tools/env.sh
terraform -chdir=entra/platform init
terraform -chdir=entra/platform plan -var-file=tenants/lab.tfvars
```

- **Local plan of nonprod** (read-only, separate working folder so you do not disturb the prod setup):

```bash
TF_DATA_DIR=~/.okta-lab/tfdata-platform-np terraform -chdir=entra/platform init -reconfigure -lock=false -backend-config=container_name=tfstate-nonprod
TF_DATA_DIR=~/.okta-lab/tfdata-platform-np terraform -chdir=entra/platform plan -lock=false -var-file=tenants/lab-np.tfvars
```

## How to add something

1. Find the Okta object in `okta-inventory/` and decide its Entra equivalent ([docs/okta-identity-engine-decision.md](../../docs/okta-identity-engine-decision.md) has the mapping table).
2. Add it here with `${var.name_prefix}` in the name, so both copies get one.
3. Shared CA building blocks (authentication strengths, more named locations) also go here. A CA policy that only one wave's apps need goes in that wave.
4. Open a pull request with a change ticket. Both plans must pass, including the Conftest rules (every CA policy excludes `bg-ca-exclusion`; every new CA policy starts report-only).

## Read next
- [../README.md](../README.md): how the three Entra roots fit together.
- [../waves/README.md](../waves/README.md): what consumes these objects.
