# Entra Legacy: the Brownfield, Imported

## What this folder is for

A real Entra tenant is never empty when a migration starts. It already has Conditional Access (CA) policies, groups, named locations and apps that people built by hand in the portal over the years. That existing estate is the **brownfield**.

This folder brings the brownfield under Terraform **without changing it**. Terraform "imports" each object: it records the object in its state file and keeps a matching description in these `.tf` files. From then on:
- The nightly drift check notices if anyone edits one of these objects in the portal.
- Later waves can refer to these objects in code instead of by copied IDs.
- Nobody can delete one by accident through Terraform (two locks, below).

In the lab, the brownfield was built by hand on 2026-10-16 to simulate a client tenant. Exit test: after import, `terraform plan` shows **zero changes** (met 2026-10-16).

## What is in it

| File | Objects | Notes |
|---|---|---|
| `ca-policies.tf` | `LAB-CA01 - All apps - Require MFA - Admins - Any location` (on) | Built with "All users", not the admin role its name says. Kept as found: a real brownfield has mislabeled policies too |
| | `LAB-CA02 - All apps - Block - All users - Legacy auth` (on) | Blocks old mail protocols (Exchange ActiveSync, "other" clients) |
| | `LAB-CA03 - Office 365 - Auth strength - Finance users - Outside office` (report-only) | Finance group, outside the office location, must meet the authentication strength below |
| `named-locations.tf` | `iac-legacy-nl-office`, `203.0.113.0/24`, trusted | A documentation IP range (RFC 5737), not a real network |
| `auth-strengths.tf` | `iac-authenticator-or-fido2` | Custom authentication strength: FIDO2 security key, or password plus Microsoft Authenticator push |
| `groups.tf` | `iac-legacy-finance-users`, `iac-legacy-privileged-admins` | The admins group holds `iac-lab-admin` |
| `app-zoom.tf` | `iac-legacy-zoom` (application and service principal) | Gallery app Zoom, no single sign-on set up. Shows what a gallery app looks like once imported |
| `imports.tf` | 9 `import` blocks, one per object | Each maps a resource address to the object's Graph path, for example `/identity/conditionalAccess/policies/<id>` |
| `locals.tf` | `bg_ca_exclusion_group_id`, `owner_user_id` | IDs of objects this root uses but does not manage (made by CLI (command-line interface) during bootstrap) |
| `variables.tf`, `tenants/lab.tfvars` | `tenant_key`, `tenant_id` | Prod only: there is no nonprod brownfield |
| `backend.tf` | State `tfstate-prod/entra/legacy/terraform.tfstate` | |
| `providers.tf`, `versions.tf` | `hashicorp/azuread` 3.10.0, Terraform 1.16.4 | Credentials come from `ARM_*` environment variables, never from a file |

## The two locks against deletion

1. **`prevent_destroy = true`** on every resource. Terraform stops with an error if any plan would delete one.
2. **Conftest rule** [policy/legacy-no-destroy.rego](../../policy/legacy-no-destroy.rego). The pipeline fails any plan for this folder that contains a delete, even if someone removed the first lock in the same pull request.

Every CA policy here also excludes the break-glass group `bg-ca-exclusion` and the owner account, so a bad change cannot lock the admins out.

## Who runs it, and how

- **Pipeline:** `plan.yml` plans it on every pull request (prod copy only); `apply.yml` applies it after merge; `drift.yml` checks it nightly.
- **Locally:** your Azure CLI login cannot read authentication strengths (it lacks the `Policy.Read.All` permission and gets HTTP 403). So local plans run as `iac-reader` with a short-lived certificate (lab shortcut; permission register row 17). The env file sets `ARM_TENANT_ID`, `ARM_CLIENT_ID`, `ARM_CLIENT_CERTIFICATE_PATH` and the certificate password; it lives outside the repo.

```bash
source lab-tools/env.sh && source ~/.okta-lab/entra-legacy-env.sh
terraform -chdir=entra/legacy init
terraform -chdir=entra/legacy plan -var-file=tenants/lab.tfvars     # expect: No changes
```

## How to change something here

- **Someone edited a brownfield object in the portal** (the drift issue tells you): either change it back in the portal, or update the `.tf` file to match through a pull request. Never let it drift silently.
- **Import another existing object:** add an `import` block and a matching resource with `lifecycle { prevent_destroy = true }`. Plan until the only action is `import`, then merge.
- **Retire a brownfield object** after its replacement is live: that is a deliberate exception. Remove it from state with a `removed` block (Terraform forgets it, Entra keeps it), then delete it by hand under a change ticket. Do not delete it through Terraform.

## Lessons from lab 1
- Import IDs must be full Graph paths (`/groups/<id>`), not bare IDs.
- Two of the three hand-built policies missed the break-glass exclusion at first. Read every policy back after building it by hand.
- A CA policy's excluded location needs the bare location ID; the code uses `basename(...)` to get it from the resource ID.

## Read next
- [../README.md](../README.md): how the three Entra roots fit together.
- [docs/build-by-hand.md](../../docs/build-by-hand.md) parts 8 and 9: building and importing the brownfield.
