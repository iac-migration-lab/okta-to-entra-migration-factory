# Entra ID Engineer Runbook

## Your role

You own the **target**: Microsoft Entra ID, written as code in [entra/](../../entra/). You build each wave's apps, keep CA (Conditional Access) policies and claims under control, approve prod applies, respond to drift, and keep break-glass access working.

Every change to a managed Entra object goes through a pull request. The portal is for reading, testing and emergencies.

## What you own

| Item | Where |
|---|---|
| Brownfield (imported, never destroyed): legacy CA policies, groups, named location, authentication strength, gallery app | [entra/legacy/](../../entra/legacy/) |
| Shared building blocks: staff groups, named locations | [entra/platform/](../../entra/platform/) |
| Migrated apps, one folder per wave: SAML and OIDC apps, claims, assignments, wave CA policies | [entra/waves/](../../entra/waves/) |
| Policy rules every plan must pass | [policy/](../../policy/) (shared with DevOps) |
| Pipeline identities' Graph permissions (`iac-reader`, `iac-planner`, `iac-applier`) | Entra → App registrations (Azure engineer assigns; you approve) |
| Break-glass accounts and group `bg-ca-exclusion` | Entra → Users, Groups |

SAML is Security Assertion Markup Language and OIDC is OpenID Connect, the two sign-in standards the apps use.

## Access you need

| Access | Production target | Lab today |
|---|---|---|
| Entra admin | Named account, PIM (Privileged Identity Management) eligible roles: Application Administrator, Conditional Access Administrator; Global Administrator only through PIM with approval | Owner is Global Administrator |
| Reading plans locally | Not needed: read the plan in the pull request's run summary | Local plans as `iac-reader` with a certificate for `entra/legacy` (to be removed) |
| GitHub | Write (pull requests); required reviewer on the `prod` environment | Owner, self-approval allowed (one-person lab) |
| Admin consent | From a break-glass account only | Owner's CLI login (shortcut) |

## Daily checks (5 minutes)
1. **Issues labeled `drift`.** None open = prod matches the code. One open = [When a drift issue opens](#when-a-drift-issue-opens). The drift run is scheduled at 10:41 UTC (Coordinated Universal Time), often later in practice.
2. **Apply runs** since yesterday (Actions → apply): all green, and each root's result says "applied, clean".
3. **Open pull requests touching `entra/`**: review plans you are asked to review.

## Weekly
- **Report-only CA policies:** check what each would have done (Entra admin center → **Sign-in logs** → open a sign-in → **Report-only** tab). Decide which are ready to turn on.
- **Sign-in failures on migrated apps** (Sign-in logs, filter by application `iac-*`): look for AADSTS50105 (user not assigned) and claims errors.
- **License end dates** (lab: Entra ID P2 trial ends 2026-11-16).

## Make a change (any change)
Status: Run 1.

1. Ask for a change ticket (lab: an issue labeled `change` + `change:scheduled`, with `window_start:` and `window_end:` lines in UTC).
2. Branch, edit the `.tf` files, run `terraform fmt -recursive` and commit.
3. Open a pull request whose first line is `Change: github:<issue number>`.
4. Read **both** plan summaries (`plan (lab-np)`, `plan (lab)`): the table per root, and the plan text in the job log. Check that every create, update and destroy is one you meant.
5. After merge: Actions → **apply** → nonprod runs by itself; check it, then approve **prod** (**Review deployments** → tick `prod` → **Approve and deploy**).
6. Each root must end "applied, clean" (or "clean after a 2nd apply" for new SAML apps). Close the ticket (`change:closed`).

## Build a wave
Status: Run 1 for build and test (wave-00); Draft for wave-01 onward.

1. **Pick the apps** with the change manager and the Okta engineer. Low-risk apps first.
2. **Read each app's Okta configuration** in `okta-inventory/app-<name>.tf`: sign-in URLs, audience, NameID format, attribute statements, assigned groups, authentication policy.
3. **Create the wave folder** (copy `entra/waves/wave-00`; change the state key in `backend.tf`). Ask the Azure engineer to create both state files before your first pull request ([entra/waves/README.md § How to add a wave](../../entra/waves/README.md#how-to-add-a-wave)).
4. **Write each app**, following wave-00:
   - SAML: non-gallery template, `preferred_single_sign_on_mode = "saml"` before the identifier, the "User" app role declared, a signing certificate made active through msgraph, `app_role_assignment_required = true`.
   - OIDC: app registration and service principal, redirect URIs, group assignment. Issue client credentials to the app owner through your secret process, never in the repo.
   - Claims: msgraph `customClaimsPolicy` (the decision from the wave-00 experiment). Never leave claims portal-only.
   - Assign the platform staff groups, not individual users.
5. **CA:** translate the Okta authentication policy rules for these apps into CA policies, report-only, excluding `bg-ca-exclusion`.
6. Pull request, plans, merge, approve prod (above).
7. **Test** ([Test sign-in](#test-sign-in)) and hand over to the Okta engineer for cutover.

## Test sign-in
Status: Run 1.

| Check | How | Pass |
|---|---|---|
| SAML sign-in | Private browser window → `https://myapps.microsoft.com` → sign in as an assigned test user → open the tile | The app (lab: IAM Showcase test page) shows NameID and every expected claim |
| OIDC sign-in | The app's own sign-in (lab: oidcdebugger.com with an ID token, lab only) | Token has the right `aud`, `iss`, `tid` and claims |
| Unassigned user | Sign in as a user not in the assigned groups | Error AADSTS50105 |
| CA (report-only) | Sign-in logs → the test sign-in → Report-only tab | The policy shows "Report-only: success/failure" as expected |

Save screenshots to `docs/evidence/` with dates in the names, cropping personal details.

## Turn a CA policy on
Status: Draft.
1. Leave it report-only for at least a week of real sign-ins. Review the report-only results (weekly check above).
2. Confirm `bg-ca-exclusion` is excluded and a break-glass sign-in works.
3. Pull request that changes **only** `state = "enabled"` on that one policy, with its own change ticket.
4. After prod apply, watch sign-in failures for an hour. To back out: a pull request back to report-only; in an emergency, set it to report-only in the portal and codify it next day.

## When a drift issue opens
Status: Draft (exit test pending).

1. Read the issue: it lists each root with the planned changes, which show what differs from the code.
2. Find who changed it: Entra admin center → **Monitoring & health** → **Audit logs**, filter by the object and the time since the last clean run. From the command line:
   ```bash
   az rest --url "https://graph.microsoft.com/v1.0/auditLogs/directoryAudits?\$filter=activityDateTime ge 2026-11-01T00:00:00Z&\$top=50" \
     --query "value[].[activityDateTime,activityDisplayName,initiatedBy.user.userPrincipalName,targetResources[0].displayName]" -o tsv
   ```
3. Decide:
   - **Put it back:** undo the portal change, or run the pipeline (Actions → apply → **Run workflow**) to re-apply the code.
   - **Keep it:** change the code to match, by pull request.
4. When the next drift run is clean, close the issue with a short note. Log it.
5. The pipeline never reverts drift by itself. Drift on a `legacy/` object can be a real brownfield owner's change: talk to them first.

## When an apply fails
Status: Run 1.

| Symptom in the log | Likely cause | Action |
|---|---|---|
| Change gate failed | Missing or expired change ticket | Fix the ticket, then Actions → apply → **Run workflow** |
| Conftest `FAIL` | The change breaks a rule (break-glass exclusion, report-only start, legacy delete) | Fix the code by pull request. Never weaken the rule to get past it |
| 404 or "inconsistent result" right after a create | Entra replication delay | The script retries once; if it still fails, re-run the workflow |
| "not clean after apply" | Something keeps differing after two applies | Read the plan in the log; usually an attribute Entra sets by itself. Add it to the code or `ignore_changes` by pull request |
| `HostNameNotOnVerifiedDomain` / app management policy error | Identifier added before SAML mode | Keep the order in the wave-00 pattern |
| "Permission being assigned was not found" | App role missing from config | Declare the role |
| `AADSTS700213` | Federated credential subject wrong | DevOps ([github-pipeline.md](github-pipeline.md)) |
| `AuthorizationPermissionMismatch` on state | State file missing, or role missing | Azure engineer ([azure.md](azure.md)) |

## Break-glass
Status: Run 1 for setup; Draft for alerts and tests.
- Two cloud-only accounts (lab: one, `bg-admin-01`), permanent Global Administrator, in group `bg-ca-exclusion`, FIDO2 security keys held separately.
- Every CA policy excludes `bg-ca-exclusion`, by code and by a Conftest rule.
- **Quarterly test:** sign in with each break-glass account, confirm no CA policy applied (sign-in log → Conditional Access tab shows "Not applied"), and record it.
- **Alert:** any break-glass sign-in should page the security team (set up a sign-in log alert; Draft).
- Admin consent for Graph permissions is given from a break-glass account only.

## Certificates and secrets to watch
- SAML signing certificates (`azuread_service_principal_token_signing_certificate`) expire. UNVERIFIED: default validity in azuread 3.10.0 is 3 years. Plan a rollover with each app owner before expiry: add a new certificate, have the app trust both, make the new one active, remove the old.
- OIDC client secrets or certificates belong to app owners; track their expiry with the owner.

## Do not
- Do not edit managed objects in the portal (anything named `iac-*`, `LAB-*`), except in an emergency.
- Do not create a CA policy outside code, or one that does not exclude `bg-ca-exclusion`.
- Do not destroy anything in `entra/legacy/`.
- Do not approve your own prod apply in production.

## Lab 1 lessons
- Read every hand-built CA policy back for the break-glass exclusion.
- The SAML "Attributes & Claims" page is wrong when a claims mapping policy is assigned; trust Graph or the code.
- Fresh SAML apps from the template carry an extra `user_impersonation` scope; the pipeline's second apply removes it.
- Start licence trials from Entra admin center → Licenses → Try/Buy, signed in as a work account in the tenant.
