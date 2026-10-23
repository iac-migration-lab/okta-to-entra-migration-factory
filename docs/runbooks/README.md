# Platform Runbooks

One runbook per platform team for operating the Okta-to-Entra migration "as code". Each tells an engineer on that team what they own, what access they need, what to check every day, how to do each routine job, and what to do when an alert fires.

| Runbook | For | Owns |
|---|---|---|
| [okta.md](okta.md) | Okta engineers | The source org, the Okta inventory, the nightly snapshot, cutover and rollback of Okta assignments, decommissioning |
| [entra.md](entra.md) | Entra ID engineers | `entra/` code, wave builds, CA (Conditional Access) policies, claims, drift response, break-glass |
| [sailpoint.md](sailpoint.md) | SailPoint engineers | Joiner, mover and leaver provisioning into Entra groups; SP-Config as code (**Draft: not built yet**) |
| [azure.md](azure.md) | Azure / cloud engineers | Subscription, budget, Terraform state storage, state recovery, role assignments for pipeline identities |
| [github-pipeline.md](github-pipeline.md) | DevOps / platform engineers | Workflows, branch protection, environments, secrets and variables, the change gate, federated credentials |

**Status of each procedure.** Every procedure carries a status, the same as [../migration-runbook.md](../migration-runbook.md): **Run 1** (worked once in the lab), **Draft** (designed, not yet run), **Proven** (worked in two or more runs). Treat Draft steps as a starting point and record what actually happens in [../findings-log.md](../findings-log.md).

**Lab versus production.** These runbooks describe the target operating model. Where the lab differs today (one tenant for both prod and nonprod, one person in every role, some shortcuts), a "Lab today" note says so. [../permission-register.md](../permission-register.md) lists every lab shortcut with what production must use instead.

## Who does what

R = does the work, A = accountable (approves), C = consulted, I = informed.

| Activity | Okta | Entra | SailPoint | Azure | GitHub / DevOps | Change manager |
|---|---|---|---|---|---|---|
| Keep the Okta inventory matching Okta | R/A | I | | | | |
| Respond to a red Okta snapshot | R/A | I | C | | | |
| Plan a wave (pick apps, check dependencies) | C | R | C | | | A |
| Build a wave in Entra (code, PR, apply) | C | R/A | | | C | I |
| Approve a prod apply | | A | | | | C |
| Test sign-in for a wave | C | R/A | | | | |
| Cut over (remove Okta assignments) | R | C | | | | A |
| Roll back (restore Okta assignments) | R | C | | | | A |
| Decommission the Okta app | R/A | I | | | | C |
| Turn a CA policy on (report-only to enabled) | | R/A | | | | C |
| Respond to an Entra drift issue | | R/A | C | | | I |
| Group membership in Entra (joiners, movers, leavers) | | C | R/A | | | |
| Terraform state storage, backups, recovery | | C | | R/A | C | |
| Pipeline identity roles and Graph permissions | C | A | | R | C | |
| Workflows, branch protection, environments, secrets | C | C | C | C | R/A | |
| Break-glass test (quarterly) | | R/A | | C | | I |

## How a wave moves between teams

```
Change manager   opens change ticket, agrees the window
      │
Entra            builds apps in entra/waves/wave-NN ─► PR ─► plan checks ─► merge
      │                                                          │
GitHub/DevOps    (pipeline runs: nonprod apply ─► prod approval ─► prod apply)
      │
Entra            tests sign-in with test users ─► evidence ─► "ready for cutover"
      │
Okta             exports current assignments ─► removes Okta assignments for the wave's apps
      │
Entra + Okta     validation window (users sign in through Entra)
      │
   OK ─► Okta decommissions the apps after the quiet period
   Not OK ─► Okta restores the assignments (rollback); Entra fixes forward by PR
```

## Alerts and who answers them

| Alert | Where it shows | First responder | Runbook section |
|---|---|---|---|
| Okta snapshot red ("Okta drift") | Actions → snapshot; GitHub email | Okta | [okta.md § Snapshot red](okta.md#when-the-snapshot-goes-red) |
| Entra drift issue (label `drift`) | Issues; GitHub email | Entra | [entra.md § Drift issue](entra.md#when-a-drift-issue-opens) |
| Apply failed | Actions → apply | Entra (code), DevOps (pipeline) | [entra.md § Failed apply](entra.md#when-an-apply-fails) |
| Change gate failed | PR checks | Author of the PR | [github-pipeline.md § Change gate](github-pipeline.md#change-gate-failures) |
| Budget alert (50, 80, 100%) | Email | Azure | [azure.md § Budget alert](azure.md#budget-alert) |
| State lock stuck | Plan or apply error "state blob is already locked" | Azure | [azure.md § Stuck lock](azure.md#stuck-state-lock) |
| Break-glass sign-in | Entra sign-in logs (alert to set up) | Entra, then security | [entra.md § Break-glass](entra.md#break-glass) |

## Rules every team follows
- **Changes to Entra go through a pull request** with a change ticket. No portal edits to managed objects. Emergency portal changes are allowed for break-glass reasons only, and must be codified or reverted by PR the next working day.
- **Never touch the break-glass exclusion.** Every CA policy excludes `bg-ca-exclusion`. A Conftest rule enforces it; do not work around it.
- **Register every grant** (role, permission, scope, token, secret, consent) in [../permission-register.md](../permission-register.md) when you make it.
- **Log what happened** in [../findings-log.md](../findings-log.md): append only, one entry per change or incident.
- **No secrets in the repo.** It is public. Private keys and secrets live in GitHub environment secrets or a vault.
