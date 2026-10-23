# SailPoint Engineer Runbook

**Status: Draft.** SailPoint is not built in the lab yet; run 1 deferred it ([../run-1-scope.md](../run-1-scope.md)). This runbook sets out the role and procedures the design expects, so the team knows its responsibilities before the first wave. Every procedure here is Draft until a run proves it.

## Your role

You own **who has access**: SailPoint ISC (Identity Security Cloud) decides, from HR (human resources) data, who gets an account and which groups they belong to, and provisions that into Entra.

The Entra code manages groups but deliberately **not their members** (`ignore_changes = [members]` in [entra/platform/groups.tf](../../entra/platform/groups.tf)). You fill those groups. That is what grants people access to migrated apps, because each app is assigned to groups, never to individuals.

You also keep SailPoint's own configuration as code: exported, reviewed, and imported through a pipeline ([sailpoint/](../../sailpoint/)).

## What you own

| Item | Where |
|---|---|
| Joiner, mover and leaver rules (who goes in which group) | SailPoint ISC: roles, access profiles, provisioning policies |
| Entra source connection (the account SailPoint uses to write Entra) | SailPoint ISC sources; credentials in a vault |
| Membership of the staff groups (`iac-it`, `iac-custserv`, `iac-finance` and later ones) | Entra, written by SailPoint |
| SailPoint configuration as code: SP-Config JSON (SailPoint's SaaS Configuration export format) | [sailpoint/](../../sailpoint/) |
| Access certifications for migrated apps | SailPoint ISC campaigns |

## Access you need

| Access | Production target | Lab plan |
|---|---|---|
| SailPoint ISC admin | Named admin, MFA (multi-factor authentication) | No real tenant; a Stoplight Prism mock built from SailPoint's published API description |
| Entra write for provisioning | A dedicated service principal with `GroupMember.ReadWrite.All` and `User.ReadWrite.All`, consented from break-glass, registered in the permission register | Not created. Lab test users are added by CLI (command-line interface) instead |
| GitHub | Write (pull requests in `sailpoint/`) | Same |

## How group membership must line up with the waves

| Okta group (source) | Entra group (target) | Fed by |
|---|---|---|
| `IT` | `iac-it` | SailPoint role or birthright rule for IT staff |
| `CustServ` | `iac-custserv` | SailPoint rule for customer service |
| `Finance` | `iac-finance` | SailPoint rule for finance |

Before a wave's cutover, the members of each Entra group must match the members of its Okta group for the people who use that wave's apps. Otherwise users lose access at cutover. You run that comparison.

## Daily checks
1. Provisioning errors to Entra: none, or each one has a ticket.
2. Leavers processed: anyone who left yesterday is removed from Entra groups (and disabled per HR policy).

## Before every cutover
1. Export the Okta group members (the nightly snapshot puts them in Azure Blob `okta-exports`; ask the Okta engineer for the run ID) and the Entra group members:
   ```bash
   az ad group member list --group iac-finance --query "[].userPrincipalName" -o tsv | sort
   ```
2. Compare by person (match on employee ID, not on email, which can differ between platforms).
3. Fix differences in SailPoint (not by hand in Entra), let it provision, compare again.
4. Sign off to the change manager: "Entra groups match for wave NN".

## Change SailPoint configuration (as code)
1. Export the current configuration (SP-Config export) and commit it on a branch.
2. Make the change in the JSON, open a pull request; the pipeline shows the difference from the live configuration.
3. After review and merge, the pipeline imports it. Secrets are stripped on export and injected at import from GitHub environment secrets; never commit them.
4. Export again and confirm no difference.

## Leaver during a validation window
A leaver must lose access in both Okta and Entra while an app is in its validation window. Confirm your leaver process removes Okta assignments and Entra group membership, and disables both accounts. Test it once per wave with a test user.

## Do not
- Do not add users to Entra groups by hand, except as a documented emergency. SailPoint would remove them again, or worse, keep stale access.
- Do not assign apps to individual users. Apps are assigned to groups; you manage the groups.
- Do not commit connector secrets or exported identity data.

## Open design questions (decide before the first real wave)
- Is SailPoint the source for Entra accounts themselves, or only for group membership (with accounts from HR-driven provisioning or Entra Connect)?
- Does Okta stay a SailPoint target until decommission, so leavers are removed from both?
- Which SailPoint ISC tenant (sandbox and production) and how the SP-Config pipeline promotes between them.
