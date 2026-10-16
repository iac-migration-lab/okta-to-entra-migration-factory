# Migration Execution Runbook (Okta to Entra, as code)

Built from what each Implementation Phase 0 (IP0) run teaches. Run 1 fills the steps in as they work; runs 2 and 3 tighten them. Each step points to the evidence in docs/findings-log.md.

Status legend: **Draft** (not run yet), **Run 1** (worked once), **Proven** (worked in two or more runs).

## 1. Prerequisites
| Step | Status | Notes |
|---|---|---|
| Source org reachable, admin with MFA (multi-factor authentication) | Run 1 | Okta Integrator Free org; read via `iac-okta-reader` |
| Target tenant with break-glass account and `bg-ca-exclusion` group | Run 1 | `bg-admin-01`, group `bg-ca-exclusion` (register #14, #15). Read every hand-built CA policy back for the exclusion: two of three missed it (findings 2026-10-16 "brownfield imported, plan clean") |
| Entra ID P1/P2 licensing for CA (Conditional Access) | Run 1 | P2 trial 2026-10-16 to 2026-11-16. Start it from Entra admin center → Licenses → Try/Buy as a work account in the tenant, not Microsoft 365 checkout |
| GitHub repo, environments `nonprod` and `prod`, reviewers | Draft | Public repo needed on the free plan |
| Tool versions pinned | Run 1 | docs/tool-install.md |

## 2. Identities and permissions
See docs/permission-register.md. Production column is the target.

## 3. Terraform state
| State key | Location | Holds | Who can read / write |
|---|---|---|---|
| `okta-inventory` | `stiaclabtfstate02/tfstate-prod/okta-inventory/terraform.tfstate` (westus3; versioning, 7-day soft delete, Entra ID auth only) | Okta groups, apps, app group assignments, zone, policies and rules, authorization server. No users or memberships (they go to Blob `okta-exports`) | Write: `iac-reader` (GitHub environment `okta-read`), owner for break-fix (register #8, #10) |
| `legacy` | `stiaclabtfstate02/tfstate-prod/entra/legacy/terraform.tfstate` | 3 CA policies, 1 named location, 1 authentication strength, 2 groups, 1 gallery app (application + service principal); all `prevent_destroy` | Write: `iac-reader` (run 1 local certificate, register #17; Lab Phase 3: `iac-applier`), owner for break-fix |
| `platform` | TBD | Shared Entra objects | TBD |
| `waves/<wave>` | TBD | One wave's apps | TBD |

## 4. Inventory (source)
| Step | Status | Notes |
|---|---|---|
| Import blocks and `-generate-config-out` | Run 1 | 29 objects; users and memberships excluded from Git. Findings 2026-10-16 "Okta inventory imported and normalized" |
| Normalize generated HCL (HashiCorp Configuration Language); time per app | Run 1 | Wrong-attribute table in the same entry; first app of each type sets the pattern, the rest are near copies |
| Nightly snapshot and drift | Run 1 | `snapshot.yml`: green run 38875055268, drift run 38875619039 (plan exit 2). Second green nightly run pending |

## 5. Per-app migration
### SAML (Security Assertion Markup Language) app
| Step | Status | Notes |
|---|---|---|
| Read Okta app settings and attribute statements from inventory | Draft | |
| Create Entra enterprise app (gallery template or custom) in a wave | Draft | |
| Claims: mapping policy vs custom claims policy | Draft | |
| Assign groups | Draft | |
| Exchange metadata with the SP (service provider) | Draft | |
| Test sign-in | Draft | |

### OIDC (OpenID Connect) app
| Step | Status | Notes |
|---|---|---|
| Read Okta client settings (redirect URIs, grant types, scopes, claims) | Draft | |
| Create Entra app registration + service principal | Draft | |
| Recreate custom claims and scopes | Draft | |
| Issue new client credentials to the app owner | Draft | |
| Test sign-in | Draft | |

## 6. Cutover wave
| Step | Status | Notes |
|---|---|---|
| Change record and PR (pull request) | Draft | |
| Plan, policy check, approval, apply | Draft | |
| Validation window | Draft | |
| Remove Okta assignments | Draft | |

## 7. Rollback
| Step | Status | Notes |
|---|---|---|
| Re-create Okta assignment; re-point SP to Okta | Draft | Time it |

## 8. Decommission
| Step | Status | Notes |
|---|---|---|
| Remove Okta app after the final validation window | Draft | |
