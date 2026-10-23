# Lab Naming

Prefix `iac` (Infrastructure as Code) everywhere. Dashes where the platform allows them; where it does not, the same words with the dashes removed.

| Object | Name | Notes |
|---|---|---|
| GitHub org | `iac-migration-lab` | Must be globally unique; if taken, append `-01`. Free plan, public. |
| GitHub repo | `okta-to-entra-migration-factory` | Renamed from `identity-as-code-lab` 2026-10-15, before any federated-credential subject existed. Public (needed for free environment gates). |
| Lab email | `la-migration-lab@outlook.com` | Created 2026-10-01. Personal Microsoft account (Outlook.com), used for every lab sign-up. Not on `lencioni.io`: that domain belongs to the owner's company Microsoft 365 tenant. Does not follow the `iac` prefix; kept as created. |
| GitHub second reviewer account | `iac-lab-reviewer` | Personal GitHub account for the `prod` required-reviewer gate (Phase 3). |
| Entra tenant display name | `IaC Migration Lab` | Display only; rename from `Default Directory` in the portal (Entra ID > Overview > Properties). |
| Entra initial domain | `lamigrationlaboutlook.onmicrosoft.com` | Tenant ID `bed5d4c3-98f0-4c73-9e4c-0b6cd3b9a0a4`. The Default Directory created with the Azure account is the lab tenant (a separate `iacmigrationlab` tenant could not be created; see findings log). Permanent. |
| Okta org | `integrator-2631921` | Created 2026-10-01, Integrator Free Plan. Org URL `https://integrator-2631921.okta.com`, Admin Console `https://integrator-2631921-admin.okta.com`. Signed up with `mark@lencioni.io` because Okta rejected the Outlook.com address (see findings log). |
| Azure subscription | `Azure subscription 1` (`6ea51c80-90de-4914-bbc6-2af9b54bba9f`) | Owner sign-in `la-migration-lab@outlook.com`. Offer `PayAsYouGo_2014-09-01`, spending limit Off. |
| Azure budget | `budget-iac-lab-monthly` | Subscription scope, $10 per month, email alerts to `la-migration-lab@outlook.com` at 50%, 80%, 100% of actual cost. Runs 2026-10-01 to 2027-09-30. Alerts only; does not stop spend. |
| Azure resource group | `rg-iac-lab` | Region `westus3` (created 2026-10-16). |
| Azure storage account | `stiaclabtfstate02` | `stiaclabtfstate` and `stiaclabtfstate01` were taken globally. Containers: `tfstate-nonprod`, `tfstate-prod`, `okta-exports`. Shared-key access off; Entra ID auth only. |
| Entra app registration (read) | `iac-reader` | Fixed by CLAUDE.md. |
| Entra app registration (plan) | `iac-planner` | Fixed by CLAUDE.md. |
| Entra app registration (apply) | `iac-applier` | Fixed by CLAUDE.md. |
| Okta service app (inventory) | `iac-okta-reader` | Read-only scopes + Read-only Administrator role. |
| Okta service app (cutover) | `iac-okta-cutover` | `okta.apps.manage` only; deactivated between waves. |
| Workstation VM | `iac-lab-ubu01` | Optional. Ubuntu Server 24.04 arm64 in UTM on the Mac, user `iac-lab`, UTM Shared Network (`192.168.64.x`). Built 2026-10-23. See [workstation-vm.md](workstation-vm.md). |
| Workstation GitHub token | `iac-lab-ubu01` | Fine-grained PAT (personal access token), this repo only, Contents and Pull requests write, 30-day expiry. Value in the password manager only. |
| Break-glass account | `bg-admin-01@lamigrationlaboutlook.onmicrosoft.com` | Display name `Break Glass 01`. Cloud-only Global Administrator, excluded from every CA (Conditional Access) policy. Group: `bg-ca-exclusion`. |
