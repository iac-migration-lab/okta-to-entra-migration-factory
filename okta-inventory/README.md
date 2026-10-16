# Okta inventory (Lab Phase 1)

Read-only Terraform for the lab Okta org `integrator-2631921`. Never applied except to record imports in state.

- `versions.tf`, `providers.tf`: Terraform `= 1.16.4`, `okta/okta` `= 7.0.0`. OAuth 2.0 service app `iac-okta-reader` (private key JWT, JSON Web Token), eight read scopes, Read-only Administrator. `max_api_capacity = 50`.
- `imports.tf`: one `import` block per seeded configuration object (29). Users and group memberships are not in Terraform; they are personal data and go to Azure Blob from the snapshot workflow, never to Git.
- One file per object type (`groups.tf`, `network-zones.tf`, `policies-*.tf`, `auth-servers.tf`) and one per app (`app-*.tf`, app plus its group assignments). Normalized by hand from `terraform plan -generate-config-out` output.
- `verify-reader.sh`: read check for the reader identity (counts only).

Local run (key stays outside the repo; the provider takes a file path):

```
source lab-tools/env.sh
export OKTA_API_PRIVATE_KEY=$HOME/.okta-lab/iac-okta-reader.pem OKTA_API_PRIVATE_KEY_ID=iac-okta-reader-2026-10-16
terraform -chdir=okta-inventory plan -detailed-exitcode
```
