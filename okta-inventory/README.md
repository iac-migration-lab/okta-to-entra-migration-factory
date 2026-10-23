# Okta Inventory: the Source, Read as Code

## What this folder is for

Before you can migrate anything, you need an exact, trustworthy list of what exists in Okta: apps, groups, policies, network zones, authorization servers, and how they connect. This folder is that list, written as Terraform.

- Every Okta configuration object is **imported**: Terraform records it in state and keeps a matching `.tf` description here.
- The files are **never applied** to change Okta. The identity Terraform uses (`iac-okta-reader`) has read-only scopes and the Read-Only Administrator role, so a write would be refused anyway.
- A **nightly snapshot** (`.github/workflows/snapshot.yml`) re-plans this folder. "No changes" means Okta still matches the files. Any difference means someone changed Okta outside the process, and the run goes red.
- The Entra side ([entra/](../entra/)) is translated from these files. Each Entra file names the Okta file it came from.

The source org is the lab Okta org `integrator-2631921`, an **Okta Identity Engine** org. Classic Engine is out of scope ([docs/okta-identity-engine-decision.md](../docs/okta-identity-engine-decision.md)).

## What is in it

### Terraform (29 imported objects)
| File | Okta objects | Admin Console name |
|---|---|---|
| `groups.tf` | Groups `IT`, `CustServ`, `Finance`; also the ID of the built-in default authentication policy | Directory → Groups |
| `app-iac-saml-custserv-desk.tf`, `app-iac-saml-finance-ledger.tf`, `app-iac-saml-hr-portal.tf`, `app-iac-saml-it-tools.tf` | 4 custom SAML (Security Assertion Markup Language) apps, each with its group assignments. hr-portal also sends profile attributes and a groups claim | Applications |
| `app-iac-oidc-portal.tf` | Custom OIDC (OpenID Connect) web app, group IT | Applications |
| `app-slack.tf` | Slack, a catalog app from the OIN (Okta Integration Network), group CustServ; placeholder workspace. Here to observe how the provider handles catalog apps | Applications |
| `network-zones.tf` | IP zone `iac-zone-office` (`203.0.113.0/24`) | Security → Networks |
| `policies-password.tf` | Password policy `iac-pwd-staff` and its rule | Security → Authenticators → Password |
| `policies-session.tf` | Global session policy `iac-gsp-staff` and its rule (the provider calls this resource `okta_policy_signon`, its Classic name) | Security → Global Session Policy |
| `policies-app-signon.tf` | Authentication policy `iac-authn-saml-apps` with rules `finance-2fa`, `office-zone` and the catch-all | Security → Authentication Policies |
| `auth-servers.tf` | Custom authorization server `iac-authz-api`: scope `iac.read`, claim `department`, policy `iac-authz-portal`, rule `allow-auth-code` | Security → API |
| `imports.tf` | 29 `import` blocks, one per object | |
| `providers.tf` | Okta provider: org, client ID of `iac-okta-reader`, its 8 read scopes, `max_api_capacity = 50` (uses at most half the API rate limit) | |
| `versions.tf` | Terraform 1.16.4, `okta/okta` 7.0.0 | |
| `backend.tf` | State `tfstate-prod/okta-inventory/terraform.tfstate` | |

**Not in Terraform, on purpose:** users and group memberships. They are personal data and the repo is public. The snapshot exports them as JSON to the Azure Blob container `okta-exports`, never to Git.

### Scripts
| File | What it does | Who runs it |
|---|---|---|
| `verify-reader.sh` | Signs in as `iac-okta-reader` with the private key, prints a count per object type, and tries one write that must be refused (HTTP 403). Proves the identity reads everything and can change nothing | You, after creating or changing the reader |
| `snapshot-export.sh` | Writes object counts (no names, no IDs) to `docs/inventory-counts.md`, and users, group members and app assignments to a temp folder for upload to Blob | `snapshot.yml` nightly |
| `seed/seed-okta-org.sh` | **Lab only.** Builds the fake Okta estate in [docs/okta-seed-spec.md](../docs/okta-seed-spec.md): 8 users, 3 groups, 6 apps, policies, a zone, an authorization server. Dry run by default; `--apply` to write. Refuses a secret file inside the repo | You, once per new lab org |
| `seed/reset-seed-passwords.sh` | **Lab only.** Sets one shared password on the seeded test users (prompted twice, never stored) | You, if the seed password went wrong |

A real migration skips `seed/`: the client's existing Okta org is the source.

## How the reader signs in

`iac-okta-reader` is an Okta API service app that signs in with a **private key** (private key JWT (JSON Web Token)), not an API token or password. The private key never sits in this repo:
- Locally: a file at `~/.okta-lab/iac-okta-reader.pem` (mode 600).
- In GitHub Actions: the secret `OKTA_PRIVATE_KEY` in the `okta-read` environment, written to a temp file for the run and deleted after.

## Run it locally

```bash
source lab-tools/env.sh
export OKTA_API_PRIVATE_KEY=$HOME/.okta-lab/iac-okta-reader.pem
export OKTA_API_PRIVATE_KEY_ID=iac-okta-reader-2026-10-16
terraform -chdir=okta-inventory init
terraform -chdir=okta-inventory plan -detailed-exitcode
```
Exit code 0 = no differences; 2 = Okta changed (the plan shows what); 1 = error.

## The nightly snapshot

`snapshot.yml` runs at 09:17 UTC (Coordinated Universal Time; GitHub often starts it a few hours late) and on demand from the Actions tab:
1. Signs in to Azure as `iac-reader` (for state and Blob) and to Okta as `iac-okta-reader`.
2. Runs the plan above. Exit 2 turns the run red ("Okta drift") and puts the plan in the run summary.
3. Writes counts and uploads the personal-data export to Blob (`okta-exports/<date>/<run id>/`).
4. Commits changed counts to the branch `inventory-counts`, not `main`. `main` is protected by required checks the bot cannot pass. Do not protect `inventory-counts`.

## When the snapshot goes red

1. Open the run summary and read the plan.
2. Check the Okta System Log for who made the change.
3. Either undo it in Okta, or accept it: update the `.tf` file to match through a pull request. The next snapshot goes green.

## Adding an object to the inventory

1. Find its ID (Admin Console URL, or an API list call; [docs/build-by-hand.md](../docs/build-by-hand.md) part 7.1 has the calls).
2. Add an `import` block. ID formats: bare ID for most objects; `<parent id>/<child id>` for policy rules and authorization server scopes, claims and policies; `<auth server id>/<policy id>/<rule id>` for authorization server rules; the app ID for `okta_app_group_assignments`.
3. Generate a starting point: `terraform -chdir=okta-inventory plan -generate-config-out=generated.tf`.
4. Tidy it into the per-type file: references instead of literal IDs, no `= null` lines, `jsonencode()` for policy rule constraints. Delete `generated.tf`.
5. Plan until the only action is `import`. If the reader cannot see the object type, it may need another read scope (register the grant).

## Known gaps (run 2)
- Authenticators and the authenticator enrollment policy are not imported yet (`okta_authenticator`, `okta_policy_mfa` with `is_oie = true`).
- System rules (for example the catch-all) ignore `network_connection` because the API returns no conditions for them.

## Read next
- [docs/build-by-hand.md](../docs/build-by-hand.md) parts 4, 5 and 7: seed, reader, inventory and snapshot.
- [docs/terraform-provider-analysis-okta-entra-sailpoint.md](../docs/terraform-provider-analysis-okta-entra-sailpoint.md): what the Okta provider can and cannot read.
