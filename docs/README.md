# docs: Plans, Records and Guides

## What this folder is for

Everything about the lab that is not code: what was planned, what actually happened, what was granted, and how to do it again. The code folders say *what* the system is; this folder says *why* it is that way and *how* it got there.

Three files are records kept as the lab runs. They are the evidence for every decision, so treat them carefully:
- **[findings-log.md](findings-log.md):** append only. One entry per step or surprise, newest at the bottom; the current run and lab phase are at the top. Never edit an old entry; correct it with a new one.
- **[permission-register.md](permission-register.md):** one row per grant (role, permission, scope, token, secret, consent), written when the grant is made, with a production verdict.
- **[evidence/](evidence/):** screenshots named `YYYY-MM-DD-short-description.png`, referenced from the findings log. Crop out personal or billing details before committing; the repo is public.

## Which document to open

### Start here
| Document | Open it when you want to |
|---|---|
| [../README.md](../README.md) | Understand the whole lab in plain words, step by step |
| [run-1-scope.md](run-1-scope.md) | Know what run 1 must prove, what is deferred, and when it is done |
| [iac-glossary.md](iac-glossary.md) | Look up a term or acronym |

### Build and operate
| Document | Open it when you want to |
|---|---|
| [build-by-hand.md](build-by-hand.md) | Build the whole lab yourself, every command and click, no AI assistant |
| [porting-guide.md](porting-guide.md) | Move this repo to new accounts: every value to replace, and the rebuild order |
| [build-phases.md](build-phases.md) | Follow the detailed steps of one lab phase |
| [tool-install.md](tool-install.md) | Install the pinned tools (Terraform, Conftest, Azure CLI and others) with checksums |
| [../.github/pipeline-guide.md](../.github/pipeline-guide.md) | See what each workflow and pipeline script does, and the GitHub settings they depend on |
| [git-check-plans-info.md](git-check-plans-info.md) | Understand the four required pull request checks, or reset branch protection with `gh api` |
| [change-gate-design.md](change-gate-design.md) | See how the change-ticket gate works and how it would connect to ServiceNow or Jira |
| [migration-runbook.md](migration-runbook.md) | Run a migration wave: the checklist each run fills in and tightens |
| [runbooks/](runbooks/README.md) | Operate one platform as its engineer: [Okta](runbooks/okta.md), [Entra](runbooks/entra.md), [SailPoint](runbooks/sailpoint.md), [Azure](runbooks/azure.md), [GitHub and pipeline](runbooks/github-pipeline.md); who owns what, daily checks, procedures, alerts |

### Reference
| Document | Open it when you want to |
|---|---|
| [okta-seed-spec.md](okta-seed-spec.md) | See exactly what the fake Okta estate contains (users, groups, apps, policies) |
| [lab-naming.md](lab-naming.md) | Find the name of any lab account or resource |
| [okta-identity-engine-decision.md](okta-identity-engine-decision.md) | Understand why only Okta Identity Engine is supported, and how Okta objects map to Entra |
| [terraform-provider-analysis-okta-entra-sailpoint.md](terraform-provider-analysis-okta-entra-sailpoint.md) | Know what each Terraform provider can and cannot manage |
| [poc-plan-identity-as-code-free-tier.md](poc-plan-identity-as-code-free-tier.md) | Read the original lab plan (Lab Phases 0 to 8) and the free-tier limits |
| [inventory-counts.md](inventory-counts.md) | Find the Okta object counts (a pointer to the `inventory-counts` branch, where the snapshot writes them) |

### History
| Document | What it is |
|---|---|
| [claude-code-prompts.md](claude-code-prompts.md) | The prompts that started each build session with Claude Code. Kept as a record; the build-by-hand guide is the AI-free path |
| [start-phase-1.md](start-phase-1.md) | A resume note from the end of Lab Phase 0 (2026-10-01). Superseded by the findings log |

## Writing rules for this folder
- File names use dashes, not underscores.
- Define every acronym in parentheses the first time a document uses it.
- Mark anything not checked against current vendor docs with `UNVERIFIED:`.
- Never write a secret, private key, token, password or exported user data here.
- When a step, command, grant or lesson changes, update the README, [build-by-hand.md](build-by-hand.md) and, if a new account-specific value appears, [porting-guide.md](porting-guide.md) in the same commit.
