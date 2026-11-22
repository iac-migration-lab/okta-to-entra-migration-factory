# Terraform Okta provider: relevant capabilities

Status: working reference, checked November 21, 2026 against the provider's release page. Items carried over from the September 30 provider analysis and not re-checked are marked UNVERIFIED.

The `okta/okta` Terraform provider is Okta's own (first-party) provider. In this program it does two jobs: it reads the whole Okta configuration every night (the inventory), and it makes a small number of tightly scoped writes during cutover (the redirect).

## 1. Version

- **Latest:** v7.0.0, released August 24, 2026. No newer release as of this date.
- **Churn:** v6.0.0 and v7.0.0 were both breaking releases, about a year apart.
- **v7.0.0 breaking changes:** attribute renames and type changes on `okta_threat_insight_settings`, `okta_role_subscription`, `okta_trusted_origin` and `okta_template_sms`; `okta_captcha_org_wide_settings` deprecated in favor of `okta_org_captcha`. None of these are on this program's critical path.
- **Rule:** pin the version and treat each major upgrade as a planned work item.

```hcl
# HCL (HashiCorp Configuration Language), the text format Terraform uses
terraform {
  required_providers {
    okta = {
      source  = "okta/okta"
      version = "~> 7.0"
    }
  }
}
```

## 2. Role in this program

| Job | Direction | Identity | When |
|---|---|---|---|
| Inventory (Step 1) | Read only | `okta-inventory` service app, read scopes | Nightly, for the whole program |
| Redirect setup | Write, one time | Separate setup identity, enabled only for setup | Once per tenant |
| Redirect per wave | Write, narrow | Cutover identity limited to the migration population | Per wave |
| App reassignment | Write, narrow | Existing cutover apps identity, disabled between waves | Per app |

## 3. Capabilities used

### 3.1 Authentication

- Three modes: API token (legacy), OAuth 2.0 service app with a private key, or a pre-obtained access token.
- **Use the OAuth 2.0 service app.** API tokens inherit the creating administrator's permissions.
- Read-only scopes exist (`okta.apps.read`, `okta.users.read`, `okta.groups.read`, `okta.policies.read` and others), so the inventory identity is read-only at the scope layer and at the admin-role layer.

```hcl
# UNVERIFIED: argument names against the pinned provider version
provider "okta" {
  org_name       = var.okta_org_name
  base_url       = "okta.com"
  client_id      = var.okta_client_id
  private_key_id = var.okta_private_key_id
  private_key    = var.okta_private_key     # from the pipeline secret store, never in Git
  scopes = [
    "okta.apps.read", "okta.groups.read", "okta.users.read",
    "okta.policies.read", "okta.idps.read",
  ]
  max_api_capacity = 50                     # use at most half of Okta's rate limit
}
```

### 3.2 Import and configuration generation (the inventory method)

- Terraform `import` blocks plus `-generate-config-out` write each existing Okta object out as HCL.
- HashiCorp still labels configuration generation experimental. It writes one file, only for import blocks with no existing resource, and often needs manual clean-up.

```hcl
import {
  to = okta_app_saml.claims_portal
  id = "0oa000000000"
}
```

```bash
terraform plan -generate-config-out=generated.tf
```

### 3.3 Okta Identity Engine (OIE) resources

- The client's org is OIE, confirmed. Resources that only work on OIE are therefore in scope, including `okta_app_signon_policy` (authentication policies) and its rules.
- This means the Conditional Access translation has the full set of Okta sign-in policies to read from.

### 3.4 Rate-limit controls

| Setting | Default | Use |
|---|---|---|
| `backoff` | true | Leave on |
| `min_wait_seconds` / `max_wait_seconds` | 30 / 300 | Leave |
| `max_retries` | 5 | Leave |
| `max_api_capacity` | none | Set to about 50 so the nightly job does not starve SailPoint and other integrations that share Okta's API quota |

### 3.5 Redirect (cutover) resources

| Purpose | Resource | Status |
|---|---|---|
| Routing rule that sends marked users to Entra | `okta_policy_rule_idp_discovery` with `user_identifier_type = "ATTRIBUTE"`, `user_identifier_attribute`, `user_identifier_patterns`, `idp_providers` | Argument names confirmed against the provider's published example |
| The built-in IdP (Identity Provider) discovery policy | `data "okta_policy"` with `type = "IDP_DISCOVERY"` | Confirmed |
| Entra as an IdP in Okta | `okta_idp_social` with `type = "MICROSOFT"`, or `okta_idp_oidc` | UNVERIFIED |
| Custom profile attribute `entraAuthState` | `okta_user_schema_property` | UNVERIFIED |
| Bookmark tile pointing at Entra My Apps | `okta_app_bookmark` | UNVERIFIED |

See `redirection-migration.md` for the full routing-rule code.

## 4. Access (least privilege)

| Grant | Minimum | Blast radius if broader | Cost of going narrow |
|---|---|---|---|
| Inventory | Read scopes only, plus a custom read-only admin role and resource set | Org Admin or Super Admin (Okta's quickstart suggests these; do not copy that) could change anything | About an hour to build the role |
| `okta.idps.manage`, `okta.policies.manage` | Setup identity, enabled only for redirect setup and the kill switch | Could redirect the whole org's sign-in to another IdP | Low: runs once |
| `okta.users.manage` | Custom role "edit user profile" on a resource set limited to the migration population | Org-wide profile tampering, including admins | About an hour |
| `okta.apps.manage` | Cutover apps identity, disabled between waves | App reassignment across the org | None; already decided |

## 5. Limits to plan around

- **Generated HCL needs a normalization pass.** For 913 SAML (Security Assertion Markup Language) apps the output is not usable as translation input as-is. Size it per app, against a sample of 20 to 30 real apps.
- **Known noise on preconfigured apps** (from the September 30 analysis): `okta_app_saml` shows a permanent difference on `attribute_statements`, `embed_url` is missing, and `features` is reset. `okta_app_oauth` does not support preconfigured apps. Because Okta is read-only and retiring, this shows up as noise in nightly snapshots, not as outages.
- **State holds personal data.** Importing `okta_user` puts profile attributes in Terraform state. The state backend must be treated like the restricted data store: encrypted, role-based access only, no local copies.
- **A few resources are not OAuth-compatible** (`okta_security_notification_emails`, `okta_rate_limiting`). Not needed here.
- **No Okta Workflows resources.** Not in use at this client.

## 6. Open points

- Whether Okta's admin API is restricted by network zone. This decides where the pipeline runners are hosted.
- Whether DynamicScale is licensed, which changes the rate-limit budget.
- The three UNVERIFIED resource names in section 3.5; confirm against the pinned version and record in `findings-log.md`.

## Sources

- Okta provider releases: https://github.com/okta/terraform-provider-okta/releases
- Okta provider, IdP discovery rule (Pulumi mirror of the Terraform docs): https://www.pulumi.com/registry/packages/okta/api-docs/policy/ruleidpdiscovery/
- Okta, Control Terraform access to Okta: https://developer.okta.com/docs/guides/terraform-design-access-security/main/
- Okta rate limits: https://developer.okta.com/docs/reference/rate-limits/
- HashiCorp, Generating configuration (experimental): https://developer.hashicorp.com/terraform/language/import/generating-configuration
- In this folder: `terraform-provider-analysis-okta-entra-sailpoint.md`, `redirection-migration.md`
