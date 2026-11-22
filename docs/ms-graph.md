# Microsoft Graph: relevant capabilities

Status: working reference, checked November 21, 2026 against Microsoft Learn and the msgraph provider's release page. Items not re-checked on this date are marked UNVERIFIED.

Microsoft Graph is the API (application programming interface) behind every Entra ID change. The azuread Terraform provider calls it for core objects. This document covers the three places the program touches Graph directly: the msgraph Terraform provider for objects azuread cannot manage, Graph PowerShell for privileged runbooks, and read queries for evidence.

## 1. The three ways we use Graph

| Route | What it is | Used for | Maturity |
|---|---|---|---|
| msgraph Terraform provider | A thin, generic layer over the Graph REST API | The short list of objects azuread does not model | Preview; v0.6.0; no 1.0 release |
| Graph PowerShell (`Microsoft.Graph` module) | Cmdlets run by a person with a delegated, just-in-time session | Domain conversion, Staged Rollout policy creation, session revocation, checks | Generally available |
| Read queries | Sign-in logs and configuration reads | Wave evidence, validation, drift | Generally available |

## 2. msgraph Terraform provider

### 2.1 Version

- **Latest:** v0.6.0, released October 1, 2026. Newer than the v0.5.0 recorded in the September 30 analysis.
- **Status:** Microsoft states the provider is in preview and subject to the Azure preview supplemental terms.
- **Release history:**

| Version | Date | What it added |
|---|---|---|
| v0.6.0 | Oct 1, 2026 | `when` attribute on `msgraph_resource_action` (run at apply or destroy); `collection_type` on `msgraph_resource_collection` |
| v0.5.0 | Aug 31, 2026 | Sovereign cloud support; `create_method` (POST or PUT) |
| v0.4.0 | Jul 16, 2026 | Import for collection resources; `skip_destroy`; default retries |
| v0.3.0 | Dec 25, 2025 | PowerShell authentication; `update_method` (PATCH or PUT); `moved` block support |
| v0.2.0 | Sep 19, 2025 | `msgraph_update_resource`, `msgraph_resource_collection`, `msgraph_resource_action` |
| v0.1.1 | Jul 9, 2025 | Initial `msgraph_resource` |

### 2.2 Building blocks

| Resource | What it does | Typical use here |
|---|---|---|
| `msgraph_resource` | Creates an object: a Graph `url` plus a `body` | New objects azuread does not model |
| `msgraph_update_resource` | Updates an object that already exists and cannot be created or deleted | Tenant-wide singleton policies, such as the authentication methods policy |
| `msgraph_resource_collection` | Manages a set of references | Membership-style relationships |
| `msgraph_resource_action` | Calls an action endpoint | One-off operations tied to apply or destroy |

- `api_version` defaults to `v1.0`. Microsoft's guidance is to use v1.0 unless what you need exists only in beta.

Microsoft's own minimal example:

```hcl
# HCL (HashiCorp Configuration Language)
resource "msgraph_resource" "group" {
  url = "groups"
  body = {
    displayName     = "My Group"
    mailEnabled     = false
    mailNickname    = "mygroup"
    securityEnabled = true
  }
}
```

Shape for a singleton policy (UNVERIFIED: exact body; test in non-production):

```hcl
terraform {
  required_providers {
    msgraph = {
      source  = "microsoft/msgraph"
      version = "0.6.0"          # exact pin; behavior can change between 0.x versions
    }
  }
}

resource "msgraph_update_resource" "auth_methods_fido2" {
  url = "policies/authenticationMethodsPolicy/authenticationMethodConfigurations/fido2"
  body = {
    "@odata.type" = "#microsoft.graph.fido2AuthenticationMethodConfiguration"
    state         = "enabled"
  }
}
```

### 2.3 What preview means in practice

- No typed schema, so no plan-time validation; mistakes surface at apply.
- Differences are comparisons of JSON bodies; drift detection depends on how faithfully Graph echoes the body back.
- Behavior can change between 0.x versions.
- **Rules for this program:** use it only for the gap list in section 3, pin an exact version, keep it in its own state key, and keep PowerShell as the fallback. Core objects (apps, groups, Conditional Access) stay on azuread.

## 3. Graph objects on the migration critical path

| Object | Graph resource | API version | Who changes it | Notes |
|---|---|---|---|---|
| Staged Rollout policy | `featureRolloutPolicy` at `/policies/featureRolloutPolicies` | v1.0 | A person, once | Creation supports delegated permissions only; application permissions are not supported. Least-privileged permission listed is `Directory.ReadWrite.All` |
| Staged Rollout membership | Group membership of the rollout groups | v1.0 | Pipeline, through azuread | Maximum 10 groups per feature; no nested or dynamic groups |
| Domain federation | `internalDomainFederation`; domain `authenticationType` | v1.0 | A person, privileged runbook | Final cutover; no Entra-side rollback afterward |
| Authentication methods policy | `authenticationMethodsPolicy` | v1.0 (UNVERIFIED on this date) | msgraph provider or PowerShell | Implements "MFA methods match Okta" and self-service password reset for the pilot |
| SAML custom claims | `customClaimsPolicy` | Beta, preview | To be decided per app | Superseded by a claims mapping policy if one is assigned |
| Tenant Governance (multi-tenant model) | Tenant governance resources | Beta | msgraph provider or manual | UNVERIFIED whether the request and accept handshake can be automated |
| Sign-in logs | `auditLogs/signIns` | v1.0 (UNVERIFIED permission: `AuditLog.Read.All`) | Read identity | Evidence that a user authenticates in the cloud, not federated |

## 4. Graph PowerShell runbook commands

Check how each domain authenticates:

```powershell
Connect-MgGraph -Scopes "Domain.Read.All"
Get-MgDomain | Select-Object Id, AuthenticationType
```

Inspect the Staged Rollout policy and who it applies to:

```powershell
Get-MgPolicyFeatureRolloutPolicy -FeatureRolloutPolicyId $id -ExpandProperty "appliesTo"
```

Revoke a user's sessions after a rollback:

```powershell
Revoke-MgUserSignInSession -UserId <upn>
```

Convert the domain to managed (final cutover, executive-approved change, run outside the pipeline):

```powershell
Connect-MgGraph -Scopes "Domain.ReadWrite.All", "Directory.AccessAsUser.All"
Update-MgDomain -DomainId <domain> -AuthenticationType "Managed"
Get-MgDomain -DomainId <domain>
```

## 5. Access (least privilege)

| Grant | Minimum | Blast radius if broader | Cost of going narrow |
|---|---|---|---|
| Staged Rollout policy creation | Delegated session by a Hybrid Identity Administrator, activated just in time | Giving the pipeline `Directory.ReadWrite.All` would allow tenant-wide object changes; Microsoft does not support application permissions for this call anyway | One manual step per tenant, recorded |
| Domain conversion | Delegated `Domain.ReadWrite.All` and `Directory.AccessAsUser.All`, just in time, under an approved change | A standing identity with this could re-federate the domain to another identity provider | A person must run it; that is intended |
| msgraph provider identity | A separate identity with only the permissions for the enumerated gap objects, in its own state | Reusing `iac-applier` widens what a preview tool can touch | One more app registration per tenant |
| Sign-in log reads | Read identity with audit log read only | Read of sign-in data, which is personal data | Treat exports as restricted |
| Beta endpoints | Use only where v1.0 has no equivalent | Microsoft does not support beta APIs in production | Record each beta use in `findings-log.md` |

## 6. Limits to plan around

- **Beta is not supported in production.** Custom claims policy and Tenant Governance are beta today.
- **Delegated-only calls cannot be automated by a pipeline identity.** Staged Rollout policy creation is the known case.
- **Staged Rollout timing.** Editing group membership can take up to 24 hours, and a user needs one more interactive sign-in before the change applies.
- **Preview provider.** Five releases in about fifteen months and no 1.0; expect change.

## Sources

- msgraph provider releases: https://github.com/microsoft/terraform-provider-msgraph/releases
- Microsoft Learn, msgraph Terraform quickstart (preview notice): https://learn.microsoft.com/en-us/graph/templates/terraform/quickstart-create-terraform
- Microsoft Graph, Create featureRolloutPolicy: https://learn.microsoft.com/en-us/graph/api/featurerolloutpolicies-post?view=graph-rest-1.0
- Microsoft Graph, featureRolloutPolicy resource: https://learn.microsoft.com/en-us/graph/api/resources/featurerolloutpolicy
- Microsoft Graph, internalDomainFederation: https://learn.microsoft.com/en-us/graph/api/resources/internaldomainfederation
- Microsoft Graph, customClaimsPolicy (beta): https://learn.microsoft.com/en-us/graph/api/resources/customclaimspolicy
- Microsoft, Staged Rollout: https://learn.microsoft.com/entra/identity/hybrid/connect/how-to-connect-staged-rollout
- Microsoft, Migrate Okta federation: https://learn.microsoft.com/en-us/entra/identity/enterprise-apps/migrate-okta-federation
- In this folder: `terraform-entra.md`, `redirection-migration.md`, `terraform-provider-analysis-okta-entra-sailpoint.md`
