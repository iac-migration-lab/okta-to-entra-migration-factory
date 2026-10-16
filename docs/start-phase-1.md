# Start Phase 1

Resume note written at the end of Phase 0 (2026-10-01). Read this, then docs/build-phases.md Phase 1.

## Where things stand
- Phase 0 closed; `Current phase: 1` in docs/findings-log.md.
- Repo: https://github.com/iac-migration-lab/okta-to-entra-migration-factory (public, `main`).
- Okta: `integrator-2631921`, Admin Console https://integrator-2631921-admin.okta.com (sign in as `mark@lencioni.io`).
- Entra / Azure: tenant `IaC Migration Lab` (`lamigrationlaboutlook.onmicrosoft.com`), subscription `Azure subscription 1`, sign in as `la-migration-lab@outlook.com` in a private window. P2 trial NOT active; do not activate it in Phase 1.
- Budget alert: $10 monthly, emails the Outlook address.

## Before starting
1. Open a terminal in the project and run:
   ```bash
   source ~/Projects/okta-to-entra-migration/lab-tools/env.sh && git pull && az account show --query user.name -o tsv
   ```
   Expect `la-migration-lab@outlook.com`. If not, run `az login --allow-no-subscriptions --use-device-code` and sign in as the Outlook address in a private window.
2. Sign in to the Okta Admin Console (also keeps the Integrator org from going inactive; 90 days without sign-in deactivates it).

## Loose ends from Phase 0
- [ ] MFA (multi-factor authentication) on `la-migration-lab@outlook.com` and on the Okta admin.
- [ ] Remove the `delete_repo` scope from the `gh` login: `gh auth refresh -h github.com -r delete_repo`.
- [ ] The budget alert was created by hand; bring it into Terraform in Phase 3.

## Phase 1 first steps
1. Pick a working free SAML test SP (service provider); samltest.id is UNVERIFIED.
2. Seed the Okta org by hand (8 users, 3 groups, apps, policies; full list in docs/build-phases.md).
3. Ask Claude for the least-privilege block for `iac-okta-reader`, then create it.
4. Settle the open question: the Phase 1 snapshot needs Terraform state and Blob storage, which the plan builds in Phase 3. Decide whether to pull the storage account and `iac-reader` forward.

## Prompt to start the session
> Start Phase 1. Read docs/start-phase-1.md and docs/build-phases.md.
