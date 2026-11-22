# Terraform Entra ID provider (azuread): relevant capabilities

Status: working reference, checked November 21, 2026 against the provider's release page. The full resource list could not be re-fetched on this date; coverage below is from the September 30 provider analysis plus the release notes since. Items not re-checked are marked UNVERIFIED.

The `hashicorp/azuread` Terraform provider is the mainstream way to manage Microsoft Entra ID as code. In this program it is the only tool that writes to Entra for core objects. What it cannot manage is handled separately (see `ms-graph.md`).

## 1. Version

- **Latest:** v3.10.0, released September 24, 2026.
- **Correction to the September 30 analysis:** that analysis recorded v3.9.0 as current. v3.10.0 was already out.
- **New in v3.10.0 that matters here:**
  - `azuread_authentication_strength_policy_fido2_combination_configuration` and the x509 equivalent. This closes a gap the analysis listed as missing (restricting which security keys count toward an authentication strength).
  - A data source for `azuread_authentication_strength_policy`.
  - `azuread_group_license` and `azuread_user_license`.
- **v3.9.0:** adds application filter conditions to Conditional Access policies.
- **v3.8.0:** raises the group create and update timeout to 30 minutes and adds consistency checks.
- **Stability:** regular releases, none of the last four labeled breaking.

```hcl
# HCL (HashiCorp Configuration Language)
terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.10"
    }
  }
}
```

## 2. Role in this program

| Job | Layer | Notes |
|---|---|---|
| Brownfield import (Step 2, Part B) | `legacy/` | Existing portal-built objects imported and protected from deletion |
| Platform objects (Step 3) | `platform/` | Break-glass, pipeline identities, persona groups, Conditional Access framework |
| Wave objects (Step 4) | `waves/` | Enterprise apps, assignments, Staged Rollout group membership |

## 3. Capabilities used

### 3.1 Authentication

- Supports OIDC (OpenID Connect) workload identity federation from GitHub Actions, so the pipeline holds no stored secret.
- One provider configuration per tenant root; a run in one GitHub environment can only obtain a token for that tenant.

```hcl
provider "azuread" {
  tenant_id = local.tenant.tenant_id
  client_id = var.pipeline_client_id   # iac-planner or iac-applier for THIS tenant
  use_oidc  = true
}
```

### 3.2 What it covers

| Area | Resources (examples) | Use here |
|---|---|---|
| Applications and service principals | `azuread_application`, `azuread_service_principal`, `azuread_application_from_template`, token signing certificates, federated identity credentials, app role assignments | The 913 SAML and 210 OIDC/OAuth apps; the Okta broker app |
| Conditional Access | `azuread_conditional_access_policy`, `azuread_named_location`, authentication strength policies | Translated Okta policies; descriptive naming |
| Groups and users | `azuread_group`, group membership, administrative units | Persona groups; Staged Rollout groups and their members |
| Roles and PIM (Privileged Identity Management) | Directory roles, custom roles, role assignments, eligibility schedule requests; PIM for groups | Just-in-time admin access |
| Entitlement Management | Access packages, catalogs, assignment policies | If governance stays partly in Entra |
| Claims | `azuread_claims_mapping_policy` and its assignment | One of two SAML claims mechanisms; see section 5 |
| Provisioning | Synchronization jobs and secrets | Not used; SailPoint is the provisioning standard |

### 3.3 Brownfield import pattern

```hcl
import {
  to = azuread_conditional_access_policy.legacy_block_legacy_auth
  id = "00000000-0000-0000-0000-000000000000"
}

resource "azuread_conditional_access_policy" "legacy_block_legacy_auth" {
  # body generated, then reviewed
  lifecycle { prevent_destroy = true }
}
```

### 3.4 New policy pattern (report-only first)

```hcl
# UNVERIFIED: argument names against the pinned provider version
resource "azuread_conditional_access_policy" "prod_ca20" {
  display_name = "PROD-CA20 - SAML apps wave 1 - Require MFA - P-EMP-MSR-PILOT - Any location"
  state        = "enabledForReportingButNotEnforced"   # every new policy starts here

  conditions {
    client_app_types = ["all"]
    applications { included_applications = ["All"] }
    users {
      included_groups = [var.personas["P-EMP-MSR-PILOT"].group_id]
      excluded_groups = [module.break_glass.exclusion_group_id]   # mandatory
    }
  }
  grant_controls {
    operator          = "OR"
    built_in_controls = ["mfa"]
  }
}
```

## 4. Access (least privilege)

| Grant | Minimum | Blast radius if broader | Cost of going narrow |
|---|---|---|---|
| Read (drift, plan refresh) | `iac-reader` with read-only Graph permissions | A leaked read token discloses configuration only | None |
| Conditional Access write | `Policy.ReadWrite.ConditionalAccess` plus `Application.Read.All` (creation returns 403 without both) | `Directory.ReadWrite.All` would allow tenant-wide object changes | Permission matrix kept per state key |
| Application write | `Application.ReadWrite.OwnedBy`, so the pipeline can change only apps it owns | `Application.ReadWrite.All` reaches every app, including the pipeline's own identities | Apps must be created or adopted by the pipeline |
| Staged Rollout group members | Pipeline is owner of those groups only | `GroupMember.ReadWrite.All` reaches privileged groups | Group ownership model to confirm in `findings-log.md` |
| Apply | `iac-applier` per tenant, federated credential bound to one GitHub environment | One multitenant applier would be write access to every tenant at once | Three registrations per tenant, set up once |

## 5. Gaps that matter to this migration

| Not in azuread | Why it matters | Handled by |
|---|---|---|
| Domain federation settings | Converting the Microsoft 365 domain from Okta federation to managed | PowerShell runbook, outside the pipeline |
| Staged Rollout policy | Moves users to Entra sign-in group by group | Created once by a person; pipeline edits group membership only |
| Authentication methods policy | Which MFA (multi-factor authentication) methods are on; self-service password reset | msgraph provider or PowerShell |
| SAML custom claims (portal "Attributes & Claims") | Per-app claims for 913 SAML apps | Decide one mechanism per app |
| Cross-tenant access settings, connected organizations | Guest and multi-tenant design | Open feature request; manual or msgraph |
| Entra Connect sync rules, Lifecycle Workflows, Terms of Use, security defaults, custom security attributes | Peripheral | Microsoft365DSC snapshot (read-only) |

- **Claims precedence:** a claims mapping policy supersedes and hides the portal's claims configuration. If an app is governed by a claims mapping policy, edits in the portal are ignored. Pick one mechanism per application and document it. This is the largest translation design question and belongs in the pilot.

## 6. Operational behavior to plan around

- **Eventual consistency.** New objects can take time to replicate; applies are slow at scale. Use generous timeouts and make re-runs safe.
- **Secrets in state.** Application passwords and service principal passwords land in Terraform state. Treat the state backend as a secret store.
- **Known bug** (from the September 30 analysis, UNVERIFIED whether fixed): `azuread_group_role_management_policy` fails when an authentication context is configured.
- **Scale.** Do not put 1,100 apps, groups and Conditional Access in one state. Split state by layer and consider one state per wave.

## Sources

- azuread releases: https://github.com/hashicorp/terraform-provider-azuread/releases
- azuread provider docs (authentication): https://github.com/hashicorp/terraform-provider-azuread/blob/main/docs/index.md
- Microsoft, Entra claims customization reference (precedence): https://learn.microsoft.com/en-us/entra/identity-platform/reference-claims-customization
- Microsoft, Conditional Access framework and policies (naming): https://learn.microsoft.com/en-us/azure/architecture/guide/security/conditional-access-framework
- In this folder: `terraform-provider-analysis-okta-entra-sailpoint.md`, `ms-graph.md`
