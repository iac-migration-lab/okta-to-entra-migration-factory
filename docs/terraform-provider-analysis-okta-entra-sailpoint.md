# Terraform Provider Analysis: Okta, Entra ID, SailPoint

Prepared for an Okta-to-Entra migration method (Identity as Code). Client-specific details removed for this public lab repo. Verified against live provider documentation, changelogs, and issue trackers on September 30, 2026. Version numbers below are as of that date.

## 1. Headline

- The three platforms are at three very different maturity levels for Terraform, and the proposal should say so plainly rather than presenting "Terraform for everything."
- Okta: mature first-party provider (okta/okta v7.0.0, released August 24, 2026). Good for the read-only inventory. Caveat: two breaking major versions in roughly twelve months.
- Entra ID: two providers. hashicorp/azuread v3.9.0 (June 18, 2026) is mature and covers the core, but has gaps that matter specifically to this migration. microsoft/msgraph v0.5.0 (August 31, 2026) fills those gaps but is officially labeled PREVIEW by Microsoft and has no 1.0 release.
- SailPoint: this analysis assumes Identity Security Cloud (ISC). No official Terraform provider exists for ISC. Two community providers exist, each maintained by one person, covering about 12% of the API, with zero to five GitHub stars. SailPoint's own supported "as code" path is the SP-Config (SaaS Configuration) API/CLI plus Configuration Hub, not Terraform.
> **POSITION STATEMENT (adopted September 30, 2026 — carry into every client-facing deliverable):**
> **Terraform is the declarative engine for Okta (read) and Entra ID (write); SailPoint is "configuration as code" through SailPoint's native SP-Config tooling in the same Git/pipeline, not through Terraform.**

## 2. Okta: okta/okta provider

### 2.1 Current state

- Latest release v7.0.0 (August 24, 2026). v6.0.0 was also a breaking release (removed deprecated resources, removed client-side validation, added Okta Identity Governance resources).
- v7.0.0 breaking changes are attribute renames and type changes on okta_trusted_origin, okta_threat_insight_settings, okta_role_subscription, okta_template_sms, okta_captcha, okta_email_template_settings; okta_captcha_org_wide_settings deprecated in favor of okta_org_captcha.
- Implication: pin the provider (`version = "~> 7.0"`) and budget an upgrade task each time a major lands. Two majors in about a year is faster churn than azuread.

### 2.2 Authentication and least privilege

- Provider supports three modes: `api_token` (SSWS, legacy), OAuth 2.0 API service app (`client_id`, `private_key_id`, `private_key`, `scopes`), or a pre-obtained `access_token`.
- Okta's own guidance recommends the OAuth 2.0 service app with a private key (PKCS#1 or PKCS#8, unencrypted) over API tokens, because API tokens inherit the creating admin's permissions and auto-renew.
- Read-only scopes exist (`okta.apps.read`, `okta.users.read`, `okta.groups.read`, `okta.policies.read`, etc.), so the Step 1 inventory identity can be read-only at the OAuth scope layer AND at the admin-role layer (custom admin role + resource set). Okta's quickstart assigns Org Admin or Super Admin to the service app; do not copy that into production.
- Caveat: a few resources are still not OAuth-compatible per the changelog (okta_security_notification_emails, okta_rate_limiting). Not needed for inventory.

### 2.3 Identity Engine versus Classic

- Several resources are Okta Identity Engine (OIE) only, including okta_app_signon_policy (authentication policies) and risk-scoring conditions in app sign-on policy rules. The resource docs state: "not compatible with Classic orgs."
- If the client's org is Classic, the inventory of authentication policies will be incomplete and the translation layer for Conditional Access has less to read from.
- **Decision (2026-10-21): Identity Engine only.** The method targets OIE orgs; a Classic org must upgrade to OIE first, as a client prerequisite outside this estimate. Check at intake with `/.well-known/okta-organization` (`"pipeline": "idx"` = OIE). Object-by-object mapping: docs/okta-identity-engine-decision.md.

### 2.4 Import and configuration generation

- Terraform's `-generate-config-out` is still labeled experimental (introduced in 1.5; formatting may change between minor versions). It writes one file, only for `import` blocks with no existing resource, and often emits conflicting attribute combinations that need manual cleanup.
- Known provider drift issues on preconfigured (Okta Integration Network) apps: okta_app_saml `attribute_statements` always showing a diff with `preconfigured_app` (#415), `embed_url` missing for preconfigured apps, `features` reset by the provider (#710). okta_app_oauth does not support preconfigured apps at all (#1030, duplicate #2648 closed).
- Impact for this engagement: since Okta is read-only and retiring, these show up as plan noise in nightly snapshots rather than outages. But the generated HCL (HashiCorp Configuration Language, the language Terraform files are written in) for a large SAML app estate will need a normalization pass before it is usable as a translation input. Budget for that.

### 2.5 Rate limits

- Okta rate limits are org-wide buckets per endpoint, with optional per-client sub-buckets; quotas vary by subscription and add-ons such as DynamicScale.
- Provider knobs: `backoff` (default true), `min_wait_seconds` 30, `max_wait_seconds` 300, `max_retries` 5, `request_timeout`, and `max_api_capacity` (percentage of the bucket Terraform will consume).
- Impact: SailPoint, other in-house integrations, and SCIM provisioning all call the same Okta management API. Set `max_api_capacity` (e.g., 50) on the inventory identity and run snapshots off-hours so nightly refreshes do not starve production integrations. Confirm with the client whether DynamicScale is licensed.

### 2.6 Other gaps

- Okta Workflows: the provider has no Workflows resources, so an org that uses them needs a manual inventory step.
- okta_user in state: the state file will contain user profile attributes. This is consistent with the decision that PII lands in Azure Storage, but the state backend now holds PII too and must be treated accordingly (encryption, private endpoint, RBAC, no state download to laptops).
- Okta Identity Governance resources (campaigns, entitlements, resource owners) exist from v6 onward but are irrelevant here because SailPoint is the IGA platform.

## 3. Entra ID: hashicorp/azuread provider

### 3.1 Current state

- v3.9.0 (June 18, 2026). Active, regular releases, no maintenance-mode or deprecation statement. 54 resources.
- Authentication supports OpenID Connect (OIDC) workload identity federation for GitHub Actions, managed identity, client certificate, client secret, Azure CLI. Federated credentials with no secrets are fully supported, which matches the Step 3 pipeline design.

### 3.2 What it covers (relevant to this program)

- Applications and service principals (including application_from_template for gallery apps, SAML token signing certificates, federated identity credentials, app role assignments, delegated permission grants).
- Conditional Access policies, named locations, authentication strength policies.
- Groups, group membership, users, invitations, administrative units.
- Directory roles, custom directory roles, role assignments, role eligibility schedule requests (Privileged Identity Management, PIM, for directory roles).
- PIM for groups: privileged_access_group_assignment_schedule, privileged_access_group_eligibility_schedule, group_role_management_policy.
- Entitlement Management: access packages, catalogs, assignment policies, resource associations.
- Claims mapping policies and their assignment to service principals.
- Synchronization jobs and secrets (Entra provisioning; not needed since SailPoint is the provisioning standard).

### 3.3 Gaps that matter to this migration

- Domain federation settings (Graph `internalDomainFederation`): not in azuread. This is the object that gets changed when the WS-Fed federation to Okta is converted to managed authentication. It is in Graph v1.0. Options: msgraph provider or PowerShell.
- Staged Rollout (Graph `featureRolloutPolicy`): not in azuread. In Graph v1.0. Limits: maximum 10 groups per feature, security groups only, no dynamic or nested groups. This constrains the wave design if the plan assumed one rollout group per business unit or per wave beyond ten.
- Authentication methods policy (which MFA methods are enabled, Self-Service Password Reset settings): not in azuread. Needed to implement the "MFA methods match Okta as-is" decision and SSPR for the pilot in code.
- SAML claims for enterprise applications: the portal "Attributes & Claims" blade writes a Graph `customClaimsPolicy`, which is beta-only in Graph and marked preview by Microsoft. azuread offers `claims_mapping_policy` instead, and per Microsoft a claims mapping policy supersedes and hides both the custom claims policy and the portal configuration. Practical consequence: pick one mechanism per application and document it, because a portal admin editing claims on an app governed by a claims mapping policy will see their changes ignored. For a large SAML app estate, this is the single largest translation-layer design question and should be in the pilot.
- Cross-tenant access settings, connected organizations, external identity policies: open feature request (#1713); not available.
- Entra Connect synchronization rules, Identity Protection legacy risk policies, Lifecycle Workflows, Terms of Use, security defaults, custom security attributes: not in azuread.
- Authentication strength "combination configurations" (e.g., restricting FIDO2 AAGUIDs): missing (#1636).

### 3.4 Operational behaviors to plan for

- Eventual consistency: v3.8.0 raised the group timeout to 30 minutes and added consistency checks; replication waits for new service principals are a known issue (#1811). Applies will be slow at scale; pipelines need generous timeouts and idempotent re-runs.
- Permissions: Conditional Access creation returns 403 unless the identity holds Policy.ReadWrite.ConditionalAccess plus Application.Read.All (#1687). Build the permission matrix per state key, not one over-privileged app.
- Bug: group_role_management_policy fails when an authentication context is configured (#1605). Relevant if PIM-for-groups activation is gated by authentication context.
- Secrets in state: application_password, service_principal_password, synchronization_secret land in state. Treat the state backend as a secret store.

## 4. Entra ID: microsoft/msgraph provider (gap filler)

- v0.5.0 (August 31, 2026; adds sovereign cloud support and a `create_method` attribute). Prior: v0.4.0 July 2026 (import for collection resources, `skip_destroy`, default retries), v0.3.0 December 2025, v0.2.0 September 2025, v0.1.1 July 2025. Five releases in fourteen months, no 1.0.
- Microsoft Learn states: "The msgraph provider for Terraform is currently in PREVIEW" and points to the Azure preview supplemental terms.
- Design: a thin generic layer over the Graph REST API. Resources: msgraph_resource (url + body), msgraph_resource_collection, msgraph_resource_action, msgraph_update_resource. `api_version` defaults to v1.0; beta is selectable but Microsoft says beta APIs are "not supported" in production.
- What this means in practice: no typed schema, so no plan-time validation; diffs are JSON body comparisons; drift detection depends on how faithfully Graph echoes the body back; import for collection resources only arrived in v0.4.0; behavior can change between 0.x versions.
- Recommendation: use msgraph only for the enumerated gap list (domain federation, Staged Rollout, authentication methods policy, and possibly custom claims policy), pinned to an exact version, in its own state key, with PowerShell as the fallback. Do not put core objects (apps, groups, CA) on it.
- Microsoft365DSC stays read-only for snapshots and drift, as already decided.

## 5. SailPoint

### 5.1 Product

- Assumed: Identity Security Cloud (ISC, formerly IdentityNow). SaaS, API-driven; everything below applies. (Had it been IdentityIQ, there would be no Terraform or SP-Config path at all; that branch is closed.)
- Assumed scope: Terraform-style code management covers sources and provisioning for the applications migrating off Okta provisioning, not the full ISC tenant.

### 5.2 Terraform options for ISC (all community, none official)

- AnasSahel/sailpoint-isc-community v2.1.1: single maintainer, 5 stars, 1 fork. Covers identity attributes, transforms, form definitions, workflows and triggers, launchers, lifecycle states, source schemas, provisioning policies, identity profiles. Self-reported "10 of 83 SailPoint v2025 endpoints (12.0%)". v2.0.0 removed access profiles and entitlements. Open bugs on workflows (#175) and form definitions (#176).
- andrefaria24/sailpoint-isc v1.1.2: a fork of the above, 0 stars, 0 forks. Adds sources, applications, entitlements. Still no access profiles or roles as resources.
- A SailPoint employee on the developer community, asked about Terraform for tenant configuration, said they were "not sure how applicable Terraform would be" and pointed to the SaaS Configuration import/export APIs as the supported path.
- Assessment: on paper the fork covers the requested scope (sources, source schemas, provisioning policies, applications). In practice the client would be adopting an unsupported dependency maintained by one person with no adoption, for a system that writes to production Active Directory. Proposing it as the standard is a reputational risk. If the client wants Terraform here, the honest framing is "the client forks and owns the provider," which is a development commitment most clients cannot staff.

### 5.3 SailPoint's supported path: SP-Config and Configuration Hub

- SP-Config (SaaS Configuration) API and the SailPoint CLI (`sail spconfig export/import`) support full export and import for: Sources, Transforms, Identity Profiles, Rules, Connector Rules, Identity Object Configuration, Event Trigger Subscriptions.
- Export-only (cannot be imported): Access Profiles, Roles, Workflows, Lifecycle States, Form Definitions, Governance Groups, Password Policies, Segments, Separation of Duties policies, Service Desk Integrations, Notification Templates, Tags, and others.
- Limitations: source passwords, secret tokens, and other sensitive data are not exported and must be re-added after import; non-employee sources cannot be imported; unsupported object types are silently skipped on import with no error; includedIds/includedNames filters only work for importable types.
- Configuration Hub: tenant-to-tenant backup, deploy, and restore of configuration objects; the GUI counterpart to SP-Config.
- Fit for this program: the requested scope (sources plus provisioning for the SCIM applications moving from Okta to SailPoint) sits entirely in the importable set. That is the good news.
- What SP-Config is not: it has no plan step, no state, and no idempotent diff. "Drift detection" has to be built as export-then-diff against Git. Promotion is an import job, not an apply. The pipeline shape (pull request, review, ServiceNow change link, apply to non-prod, then prod) can be identical to the Terraform pipeline; the tool underneath is the CLI.

### 5.4 Recommendation

- Position SailPoint as "configuration as code via SailPoint's native SP-Config tooling," in the same repository and pipeline, with the same review gates. Do not position it as Terraform.
- Each migrated SCIM app becomes a SailPoint source (SCIM 2.0 or Web Services connector). Source definitions and provisioning policies live in Git as SP-Config JSON; credentials come from the secrets pipeline at import time because SP-Config strips them.
- Roles and access profiles that reference those sources are export-only, so they remain portal-managed (or Configuration Hub-managed) and are snapshotted for drift only. Say this explicitly to the client so "SailPoint as code" is not over-promised.

## 6. Cross-cutting cautions

- Terraform licensing: Terraform Community Edition is Business Source License 1.1. Fine for a client's internal use.
- Secrets and PII in state: Okta user profiles, Entra application and service principal passwords, synchronization secrets. Azure Storage backend needs encryption, private endpoint, RBAC scoped to the pipeline identities, soft delete and versioning, and no local state. Terraform 1.11+ write-only arguments and ephemeral values reduce what lands in state; verify per resource before relying on it.
- Provider version churn: pin every provider with an exact or `~>` constraint; schedule upgrades as work items. Okta has shipped two breaking majors in about a year; msgraph is 0.x and can change at any minor.
- Scale: Hundreds of SAML and OIDC apps plus groups and CA in one state would make plan times and rate-limit exposure unacceptable. The existing decision to split state keys (legacy, platform, wave objects) stands; consider one state per wave.
- Skills: the gap list in section 3.3 means whoever does the hands-on build will be writing Graph JSON bodies or PowerShell in addition to HCL (HashiCorp Configuration Language). Size the enablement accordingly.

## 7. Action items

- [ ] **Reframe the scope language.** Check any proposal or statement of work for wording that implies Terraform or "Identity as Code" covers SailPoint. Replace with the position statement in section 1. Specifically check: the IaC workstream description, the migration-factory description, the "SCIM apps move to SailPoint provisioning" line, deliverable names, and any effort estimate that assumes one toolchain for all three platforms.
- [ ] Add the SailPoint SP-Config pipeline (export, diff, import via SailPoint CLI) as its own named workstream with its own estimate, rather than a line inside the Terraform workstream.
- [ ] State in the proposal that Roles and Access Profiles in ISC remain portal- or Configuration Hub-managed and are snapshotted for drift only.
- [ ] **Budget for HCL (HashiCorp Configuration Language) normalization of the Okta SAML inventory output.** The `terraform import` plus `-generate-config-out` pass over a large SAML app estate will produce HCL that is not usable as a translation-layer input as-is: the generator is experimental, emits conflicting attribute combinations, and the okta_app_saml resource has known noise on preconfigured apps (`attribute_statements` always diffs, `embed_url` missing, `features` reset). Add an explicit work package to the Step 1 / Step 2 estimate for cleaning, de-duplicating, and structuring that output into the canonical form the Entra translation consumes. Size it per application, not as a one-time task, and confirm the estimate against a sample of 20 to 30 real apps from the client's Okta org before committing a number.

## 8. What to say to the client

- "Terraform is the declarative engine for Okta inventory and Entra ID configuration. The first-party providers cover the core objects: applications, groups, Conditional Access, roles, PIM, access packages."
- "Four Entra objects on the migration critical path are not in the mainstream provider: domain federation, Staged Rollout, the authentication methods policy, and SAML claims for enterprise apps. We handle those through Microsoft's Graph provider, which Microsoft labels preview, or through PowerShell, in a separate isolated state. We are telling you this now so it is not a surprise in the pilot."
- **"Terraform is the declarative engine for Okta (read) and Entra ID (write). SailPoint is configuration as code through SailPoint's native SP-Config tooling, in the same Git and change pipeline, not through Terraform."** Then: "SailPoint does not have a supported Terraform provider. SailPoint's own tooling covers sources and provisioning policies, which is exactly what this program needs. Roles and access profiles remain portal-managed."
- "This method is built for Okta Identity Engine. We confirm your org is on Identity Engine before sizing; if it is still on Classic, the upgrade to Identity Engine is a prerequisite you plan first. We also need to know whether API access is IP-restricted and whether DynamicScale is licensed."
- "For the SailPoint workstream we need to know whether Configuration Hub is enabled on your tenants, whether a non-prod ISC tenant exists that mirrors prod, and which connector types (SCIM 2.0, Web Services, or others) the migrating applications will use."

## 9. Open questions to close before the proposal

- Confirm the Okta org is Identity Engine (decision: OIE only; Classic must upgrade first). Network-zone restriction on the management API.
- Okta rate-limit tier and whether DynamicScale is licensed.
- SailPoint: whether Configuration Hub is enabled, whether a non-prod ISC tenant exists, and the connector types planned for the migrating applications (secrets handling differs per connector since SP-Config strips credentials).
- Number of Entra Staged Rollout groups the wave plan assumes (limit is 10 per feature).
- Whether any Entra applications already use claims mapping policies (they would silently override portal claims).
- Terraform version floor (1.11+ for write-only arguments) and whether the client is on HCP Terraform or CE.

## Sources

- Okta provider releases: https://github.com/okta/terraform-provider-okta/releases
- Okta provider changelog: https://github.com/okta/terraform-provider-okta/blob/master/CHANGELOG.md
- Okta provider configuration docs: https://github.com/okta/terraform-provider-okta/blob/master/docs/index.md
- okta_app_signon_policy (OIE-only note): https://github.com/okta/terraform-provider-okta/blob/master/docs/resources/app_signon_policy.md
- Okta: Control Terraform access to Okta: https://developer.okta.com/docs/guides/terraform-design-access-security/main/
- Okta: Enable Terraform access for your Okta org: https://developer.okta.com/docs/guides/terraform-enable-org-access/main/
- Okta rate limits: https://developer.okta.com/docs/reference/rate-limits/
- Okta provider issues: #415 https://github.com/okta/terraform-provider-okta/issues/415, #710 https://github.com/okta/terraform-provider-okta/issues/710, #2648 https://github.com/okta/terraform-provider-okta/issues/2648
- Terraform generating configuration (experimental): https://developer.hashicorp.com/terraform/language/import/generating-configuration
- azuread releases: https://github.com/hashicorp/terraform-provider-azuread/releases
- azuread resource list: https://github.com/hashicorp/terraform-provider-azuread/tree/main/docs/resources
- azuread provider docs (authentication): https://github.com/hashicorp/terraform-provider-azuread/blob/main/docs/index.md
- azuread issues: #1713 https://github.com/hashicorp/terraform-provider-azuread/issues/1713, #1687 https://github.com/hashicorp/terraform-provider-azuread/issues/1687, #1636 https://github.com/hashicorp/terraform-provider-azuread/issues/1636, #1605 https://github.com/hashicorp/terraform-provider-azuread/issues/1605, #1811 https://github.com/hashicorp/terraform-provider-azuread/issues/1811, #868 https://github.com/hashicorp/terraform-provider-azuread/issues/868
- msgraph provider repo and releases: https://github.com/microsoft/terraform-provider-msgraph, https://github.com/microsoft/terraform-provider-msgraph/releases
- Microsoft Learn msgraph quickstart (preview notice): https://learn.microsoft.com/en-us/graph/templates/terraform/quickstart-create-terraform
- Graph internalDomainFederation: https://learn.microsoft.com/en-us/graph/api/resources/internaldomainfederation
- Graph featureRolloutPolicy: https://learn.microsoft.com/en-us/graph/api/resources/featurerolloutpolicy
- Graph customClaimsPolicy (beta): https://learn.microsoft.com/en-us/graph/api/resources/customclaimspolicy
- Entra claims customization reference (precedence): https://learn.microsoft.com/en-us/entra/identity-platform/reference-claims-customization
- Entra custom claims policy (preview): https://learn.microsoft.com/en-us/entra/identity-platform/claims-customization-custom-claims-policy
- SailPoint community provider: https://github.com/AnasSahel/terraform-provider-sailpoint-isc-community
- SailPoint community provider fork: https://github.com/andrefaria24/terraform-provider-sailpoint-isc
- SailPoint SaaS Configuration (SP-Config) object support: https://developer.sailpoint.com/docs/extensibility/configuration-management/saas-configuration/
- SailPoint Configuration Hub: https://developer.sailpoint.com/docs/extensibility/configuration-management/configuration-hub/
- SailPoint community thread on configuration as code: https://developer.sailpoint.com/discuss/t/any-sort-of-configuration-as-code-methodology-promote-to-production-etc/3542