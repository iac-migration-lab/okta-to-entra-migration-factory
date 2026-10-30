# Identity as Code Lab

Personal proof of concept of an Okta-to-Microsoft Entra ID migration run "as code", with SailPoint as the provisioning standard. The owner is a buy-side IAM (Identity and Access Management) architect learning the method hands-on, not a developer.

## Implementation Phase 0 (this repo)
- **Name:** Claude Identity as Code Implementation Phase 0 (IP0). It covers this repo, the lab Okta org (`integrator-2631921`), and the lab Entra tenant (`lamigrationlaboutlook.onmicrosoft.com`). Later implementation phases move toward the real client build.
- **Purpose:** prove identity as code end to end: GitHub (CI/CD (continuous integration and delivery) pipelines, state, gates), Okta as the source, Entra as the target, and migration of basic OIDC (OpenID Connect) and SAML (Security Assertion Markup Language) apps.
- **Deliverables:** working code and pipelines; Terraform state information (backend, keys, what each state holds); docs/permission-register.md; docs/migration-runbook.md, a migration execution runbook built from what each run teaches.
- **Runs:** the owner will run IP0 at least three times before building for real. Current run is at the top of docs/findings-log.md. **Run 1 goal: see it all work.** Favor progress over polish; record shortcuts so later runs can remove them.
- **Inside IP0,** the numbered plan phases in docs/poc-plan-identity-as-code-free-tier.md are called "lab phases" (Lab Phase 0 to 8). "Phase N" in older findings entries means Lab Phase N.
- **Environments are throwaway:** personal free accounts, dummy data only, nothing to do with any client.

## Read first, every session
- docs/run-1-scope.md: narrows run 1 to three proof points (Okta discovery as code, Entra write path as code, CI/CD between the two) and defers Lab Phases 5, 6, 7.
- docs/findings-log.md: current run and lab phase at the top; what has actually happened. Append, never rewrite.
- docs/build-phases.md: step-by-step run book per lab phase.
- docs/permission-register.md: every grant made so far.
- docs/poc-plan-identity-as-code-free-tier.md and docs/terraform-provider-analysis-okta-entra-sailpoint.md as needed.
- docs/iac-glossary.md for plain-language term definitions.
- docs/okta-identity-engine-decision.md: the source Okta org is Identity Engine only; use OIE resources and terms.

## Keep README.md current
README.md is the step-by-step guide for a layperson. Update it in the same commit whenever a lab phase or session changes status, steps, names, versions, commands, or lessons learned: the Status line, the step markers in section 6, section 7 lessons, and the "Last updated" line.

In the same commit, also update docs/build-by-hand.md (a full manual build with no AI assistant) when a step, command, grant or lesson changes, and docs/porting-guide.md plus the `$tokens` strip list in docs/porting-guide-windows.md section 4 when a new account-specific value (ID, name, URL) enters the code.

## Hard rules (still absolute)
- Never reference or configure the owner's company Microsoft 365 tenant (`lencioni.io`), company SharePoint, any production GitHub organization, or any client environment. Never connect the lab Okta org to `lencioni.io`. If a step would, stop and say so.
- Never write a secret, private key, API token, client secret, or exported user JSON into the repo, CLAUDE.md, or a commit (the repo is public). Local secrets live under `~/.okta-lab/` (chmod 600); pipeline secrets live in GitHub environment secrets.

## Autonomy in the lab
The owner pre-approves any permission, scope, role, or secret in the lab accounts, and any create, change, or delete of lab resources. Do what the run needs without asking; the owner is working on other things in parallel.
- Ask only before: touching anything outside the lab accounts; anything that costs money beyond the $10 monthly budget alert or needs a paid SKU (stock keeping unit, a paid product tier); deleting a whole account, tenant, org, or the repo; force-pushing `main`.
- When only the owner can do something (console-only step, browser sign-in), give one copy-pasteable command or a short click path and ask for the output.
- Prefer the pipeline for changes to migrated objects (Entra apps, CA (Conditional Access) policies, waves), because proving the pipeline is the point. Local `terraform apply`, CLI (command-line interface) calls, and scripts are allowed for bootstrap and to get unstuck; log each one in the findings log.
- Activate the Entra ID P2 trial when the lab reaches work that needs it; log the date.

## Permission register (replaces the least-privilege gate)
For every grant (scope, admin role, Graph permission, RBAC (role-based access control) role, token, secret, consent), add a row to docs/permission-register.md **at the time of the grant**: identity, what was granted, why, run, production verdict (OK / not OK / OK with changes), and what production should use instead. Broad grants are fine in the lab; an unregistered grant is not.

Production target design (what the register compares against):
- Okta: Identity Engine (OIE) orgs only; Classic is out of scope and must upgrade first (docs/okta-identity-engine-decision.md). Use OIE resources and terms (authentication policy, global session policy, authenticators), never Classic factors.
- Okta: OAuth 2.0 service apps with private key JWT (JSON Web Token), no SSWS API tokens; read-only scopes + Read-only Administrator for inventory; `okta.apps.manage`-only cutover identity, disabled between waves.
- Entra: `iac-reader`, `iac-planner`, `iac-applier` with GitHub Actions federated credentials, no client secrets, Graph application permissions scoped per phase, admin consent from break-glass only.
- Break-glass excluded from every CA policy, by module and by Conftest rule. Keep this in the lab too, so we don't lock ourselves out.

## How to answer
- Define every acronym in parentheses on first use, including HCL (HashiCorp Configuration Language).
- Verify provider arguments, CLI flags, and portal paths against current docs; prefix anything unverified with `UNVERIFIED:`. In run 1, try it and log the result rather than stalling on verification.
- Outline format. Short.
- One question per turn at most.
- Pin every provider and tool version. Record versions in findings-log.md.
- File names use dashes, not underscores.

## Repo layout
okta-inventory/   Terraform for the Okta org (import blocks, generated + normalized HCL); seed/ holds the one-off seeding script
entra/legacy/     brownfield-imported Entra objects, prevent_destroy on everything
entra/platform/   new shared Entra objects (groups, named locations, auth strengths, CA)
entra/waves/      per-wave app migrations
sailpoint/        SP-Config JSON and the mock-server pipeline
policy/           Conftest (OPA, Open Policy Agent) rules
.github/workflows/  snapshot, plan, apply, drift, change-gate
docs/             plan, analysis, findings-log, permission register, migration runbook, glossary, retro
README.md         layperson's step-by-step guide; keep current

## Commands
source lab-tools/env.sh                             # pinned tools on PATH
terraform fmt -recursive && terraform validate     # before every commit
conftest test --policy policy/ <plan.json>          # policy check on a plan
sail --version                                      # SailPoint CLI present

## Findings entry template
## YYYY-MM-DD, Run N, Lab Phase N, short title
- What the docs said:
- What actually happened:
- Time taken:
- Evidence:
- Change to the client plan, if any:
- Accepted risks added, if any:
