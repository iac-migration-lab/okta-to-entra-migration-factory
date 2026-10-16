# Entra legacy

Brownfield Entra objects created by hand in the portal (2026-10-16), imported into Terraform. `prevent_destroy` on every resource. Exit: `terraform plan` shows zero changes after import (met 2026-10-16).

| File | Objects |
|---|---|
| `ca-policies.tf` | `LAB-CA01`, `LAB-CA02` (on), `LAB-CA03` (report-only); all exclude `bg-ca-exclusion` and the owner |
| `named-locations.tf` | `iac-legacy-nl-office` |
| `auth-strengths.tf` | `iac-authenticator-or-fido2` |
| `groups.tf` | `iac-legacy-finance-users`, `iac-legacy-privileged-admins` |
| `app-zoom.tf` | gallery app `iac-legacy-zoom` (application + service principal) |
| `imports.tf` | one import block per object |
| `tenants/<tenant_key>.tfvars` | tenant ID per tenant |

## Run locally (run 1)
The Azure CLI token lacks `Policy.Read.All`, so run 1 plans as `iac-reader` with a local certificate (permission register #17). The env file sets `ARM_CLIENT_ID`, `ARM_TENANT_ID`, `ARM_CLIENT_CERTIFICATE_PATH`; it holds no secret.

```
source lab-tools/env.sh && source ~/.okta-lab/entra-legacy-env.sh
cd entra/legacy && terraform init && terraform plan -var-file=tenants/lab.tfvars
```

Conftest rule (Lab Phase 3): no resource in this folder may be destroyed.
