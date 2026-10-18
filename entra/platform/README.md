# Entra platform

New shared Entra objects. State key `entra/platform/terraform.tfstate` in `tfstate-prod`.

| File | Objects |
|---|---|
| `groups.tf` | `iac-it`, `iac-custserv`, `iac-finance` (one per Okta group; membership not managed here) |
| `named-locations.tf` | `iac-nl-okta-office` (Okta zone `iac-zone-office`) |

Apply order: platform, then `entra/waves/*` (waves read the groups by name).

Conftest rules: every CA policy excludes the break-glass group `bg-ca-exclusion`; every new CA policy starts in report-only (`enabledForReportingButNotEnforced`).

Two copies in the one lab tenant: `tenants/lab.tfvars` (prod, `iac-*`) and `tenants/lab-np.tfvars` (nonprod, `iac-np-*`, state in `tfstate-nonprod`). Applied by `apply.yml` only.
