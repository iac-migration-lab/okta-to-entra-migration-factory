# Redirection migration: strategy and configuration

Status: working reference, November 21, 2026. Source: the draft runbook `claude/client-redirected-migration.md` (RB-23), checked on this date against current Microsoft and Okta documentation. Items not confirmed are listed under "Still unverified". Client-identifying names are withheld.

The redirect strategy moves each wave's users from Okta sign-in to Microsoft Entra ID sign-in automatically, using two switches per user that the pipeline keeps in step.

## 1. The strategy

- **Goal:** a user who types their username at the Okta sign-in page lands on the Entra sign-in page, with no new bookmarks or instructions.
- **Rollback:** a pull request (PR) at user, wave or app level, without touching vendor consoles for most failures.
- **Why it suits a long migration:** apps can stay behind Okta while users already authenticate in Entra, so users and apps move on separate schedules.
- **Platform assumption:** the client's Okta org is Okta Identity Engine (OIE), confirmed. The routing-rule design below is written for OIE.

## 2. How it works: two switches

| Switch | Platform | Mechanism | Effect when on |
|---|---|---|---|
| A | Entra ID | Membership of a Staged Rollout group | Entra checks the password itself through PHS (Password Hash Sync) instead of sending the user to Okta |
| B | Okta | Profile attribute `entraAuthState = "entra"`, matched by an IdP (Identity Provider) routing rule | Okta sends the user to Entra to sign in |

- **Order:** A then B going forward; B then A rolling back.
- **Why order matters:** if B is on and A is off, Okta sends the user to Entra and the federated domain sends them back to Okta. Microsoft documents this sign-in loop.
- **Safe intermediate state:** A on, B off. The user still starts at Okta for Okta-fronted apps, while Microsoft 365 and Entra-fronted apps authenticate in Entra.
- **Why an attribute, not a group:** Okta evaluates routing rules before it knows the user's group membership, so a rule cannot match on a group. Matching a user attribute is the documented workaround.

### Stages per user

| Stage | Name | Switch A (Staged Rollout) | Switch B (Okta attribute) | Apps rely on | How to roll back |
|---|---|---|---|---|---|
| S0 | On Okta | Off | `okta` | Okta | Nothing to roll back |
| S1 | Entra-ready | On | `okta` | Okta | Remove the user from the rollout group |
| S2 | Redirected | On | `entra` | Okta, passing through to Entra | Reset the attribute, then remove the user from the group |
| S3 | App on Entra | On | `entra` | Entra (domain still federated to Okta) | User: remove from the group. App: restore its Okta settings |
| S4 | Validated | On | `entra` | Entra; Okta app unassigned | As S3, until Okta access is removed |
| S5 | Domain converted | n/a | n/a | Entra | None; the Okta fallback ends here |

## 3. Configuring the Entra side

### 3.1 Prerequisites

- PHS and Seamless SSO (single sign-on) enabled in Entra Connect. Client believes PHS is on; not yet verified.
- The same UPN (User Principal Name) in Okta and Entra for every wave user, or another common matching attribute.
- Check the domain's current state:

```powershell
Connect-MgGraph -Scopes "Domain.Read.All"
Get-MgDomain | Select-Object Id, AuthenticationType
```

### 3.2 Staged Rollout policy (one time, by a person)

- **Role:** Hybrid Identity Administrator.
- **Not a pipeline step:** creating the policy through Microsoft Graph (`featureRolloutPolicy`) supports delegated permissions only. An application identity cannot create it.
- **Portal path:** Entra admin center > Entra ID > Entra Connect > Connect Sync > Enable staged rollout for managed user sign-in > Manage groups.
- **Group design limits:**
  - Maximum 10 groups per feature.
  - No nested groups and no dynamic groups.
  - 200 users maximum the first time a group is added.
  - Cloud security groups recommended; on-premises groups add sync latency.

### 3.3 Broker app registration (lets Okta use Entra as an IdP)

- **Permissions:** delegated Microsoft Graph `openid`, `profile`, `email` only, with admin consent.
- **Credential:** a client secret, held by Okta. Never in Git.
- **Redirect:** Okta's redirect URI on a Web platform entry, with access tokens and ID tokens switched on.
- **Assignment:** only the Staged Rollout groups.

```hcl
# HCL (HashiCorp Configuration Language) - entra/platform/okta-broker.tf
resource "azuread_application" "okta_broker" {
  display_name     = "PROD-APP - Okta Broker - OIDC - Wave Users"
  sign_in_audience = "AzureADMyOrg"   # single tenant; see "Still unverified"
  web {
    redirect_uris = ["https://<okta-org>.okta.com/oauth2/v1/authorize/callback"]
    implicit_grant {
      access_token_issuance_enabled = true
      id_token_issuance_enabled     = true
    }
  }
  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph
    resource_access {   # openid
      id   = "37f7f235-527c-4136-accd-4a02d197296e"
      type = "Scope"
    }
    resource_access {   # profile
      id   = "14dad69e-099b-42c9-810b-d002981feec1"
      type = "Scope"
    }
    resource_access {   # email
      id   = "64a6cdd6-aab1-4aaf-94b8-3cc8405e90d0"
      type = "Scope"
    }
  }
  lifecycle { prevent_destroy = true }
}
```

## 4. Configuring the Okta side

### 4.1 Profile attribute

- Custom string `entraAuthState`, values `okta` or `entra`, default `okta`, writable by admins only.
- Microsoft's own tutorial does the same with an unused attribute (Division set to ToAzureAD for a test user).

### 4.2 Entra as an IdP

- **Console path:** Security > Identity Providers > Add Microsoft.
- Paste the broker app's Application ID as Client ID and the secret as Client Secret.
- Link accounts by UPN. Leave automatic (just-in-time) provisioning off.

```hcl
# okta-cutover/routing.tf   (UNVERIFIED: resource type and arguments against the pinned okta provider)
resource "okta_idp_social" "entra" {
  type                = "MICROSOFT"
  name                = "Entra ID (prod tenant)"
  protocol_type       = "OIDC"
  scopes              = ["openid", "profile", "email"]
  client_id           = var.entra_broker_client_id
  client_secret       = var.entra_broker_client_secret   # from a GitHub environment secret, never in tfvars
  account_link_action = "AUTO"
  provisioning_action = "DISABLED"
  username_template   = "idpuser.userPrincipalName"
}
```

### 4.3 Routing rule

- One rule, placed above the default rule: if `entraAuthState` equals `entra`, route to the Entra IdP.
- Placement matters: Okta applies the first active rule a user matches.
- **Console path:** Security > Identity Providers > Routing Rules > Add Routing Rule.

```hcl
data "okta_policy" "idp_discovery" {
  name = "Idp Discovery Policy"
  type = "IDP_DISCOVERY"
}

resource "okta_policy_rule_idp_discovery" "to_entra" {
  policy_id = data.okta_policy.idp_discovery.id
  name      = "Route entraAuthState=entra to Entra ID"
  priority  = 1
  status    = var.redirect_enabled ? "ACTIVE" : "INACTIVE"   # kill switch
  idp_providers {
    id   = okta_idp_social.entra.id
    type = "MICROSOFT"          # UNVERIFIED type string; the provider's example shows "OIDC"
  }
  user_identifier_type      = "ATTRIBUTE"
  user_identifier_attribute = "entraAuthState"
  user_identifier_patterns {
    match_type = "EQUALS"
    value      = "entra"
  }
}
```

## 5. Keeping the switches in step

- **One wave file drives both platforms.** The Entra pipeline and the Okta cutover job both read it.

```yaml
# waves/wave-03.yaml
wave: 3
business_unit: BU-C
sr_group: SR-Wave03-BUC          # one of the 10 Staged Rollout groups
target_state: S2                 # S0..S4
change_record: CHG0000000
okta_removal_date: null
users:
  - upn: user1@client.example
    state_override: null         # e.g. S0 to pull one user back
apps:
  - okta_id: 0oa000000000
    entra_app: PROD-APP - Claims Portal - SAML
    target: okta                 # okta | entra  (S3 sets entra)
    rollback_owner: app-owner@client.example
```

- **Policy check.** A Conftest rule (OPA, Open Policy Agent) rejects any plan where the switches disagree.

```rego
# policy/redirect-pairing.rego
package redirect

deny[msg] {
  some u
  input.okta_attr[u] == "entra"
  not input.sr_members[u]
  msg := sprintf("%s redirected to Entra but not in a Staged Rollout group (sign-in loop)", [u])
}
```

- **Job order.** The workflow enforces A before B going forward, and attribute reset before group removal on rollback.

## 6. Forward procedure per wave

| Step | Action | Timing |
|---|---|---|
| 1 | Confirm gates: PHS, Seamless SSO, MFA (multi-factor authentication) registration, Conditional Access in report-only for 5 days, break-glass test within 7 days | T-2 days |
| 2 | PR sets `target_state: S1`. Apply adds users to the Staged Rollout group (switch A) | T0 |
| 3 | Confirm in Entra sign-in logs that each wave user authenticates in the cloud, not federated | Before step 4; see Correction 1 |
| 4 | PR sets `target_state: S2`. The Okta job sets `entraAuthState=entra` (switch B) only for users confirmed in step 3 | After step 3 |
| 5 | A pilot user opens an Okta-fronted app, lands on Microsoft sign-in, and returns to the app | Same day |
| 6 | Monitor 5 business days; sign-in failures under 2 percent | T0 + 1 to 6 days |
| 7 | Per app: PR sets `apps[].target: entra`, then the vendor-side switch | Per app |
| 8 | After the app's validation window, set `target_state: S4` | Per app criticality |

## 7. Rollback

- **One user:** PR sets `state_override: S0`. The pipeline resets the attribute, then removes group membership. Optionally revoke sessions: `Revoke-MgUserSignInSession -UserId <upn>`.
- **Whole wave:** PR sets `target_state: S0`.
- **Everyone, urgently:** set `redirect_enabled = false`, which deactivates the routing rule.
- **One app with a claims, certificate or NameID fault:** restore its Okta metadata in the vendor console, reassign the Okta app.
- **After domain conversion (S5):** no Entra-side rollback remains. Conversion is a privileged runbook outside the pipeline:

```powershell
Connect-MgGraph -Scopes "Domain.ReadWrite.All", "Directory.AccessAsUser.All"
Update-MgDomain -DomainId <domain> -AuthenticationType "Managed"
Get-MgDomain -DomainId <domain>
```

## 8. Least privilege

| Grant | Minimum | Blast radius if broader | Cost of going narrow |
|---|---|---|---|
| Okta `okta.idps.manage` and `okta.policies.manage` | Separate setup identity, enabled only for setup and the kill switch | Could redirect the whole org's sign-in to another IdP | Low: setup runs once |
| Okta user profile write | Custom admin role limited to the migration population | Org-wide profile tampering, including admins | About 1 hour to build the role and resource set |
| Entra Staged Rollout policy | Created once by a person with a delegated session | Pipeline holding `Directory.ReadWrite.All` tenant-wide | Low: one manual step, recorded |
| Entra group membership | Pipeline is owner of the Staged Rollout groups only | Membership of every group, including privileged ones | Group ownership model needs a findings-log check |
| Broker app secret | Stored only in Okta, 6-month expiry, never in Git | Impersonation of the broker client | Recorded accepted risk until key-based authentication is verified |

## 9. Corrections to the draft runbook (RB-23)

1. **Staged Rollout timing is slower than the draft assumes.**
   - The draft waits 30 minutes after switch A and says federation "resumes within minutes" on rollback.
   - Microsoft states that edits to a group's membership can take up to 24 hours, and that a user who is added or removed needs one more interactive sign-in before the change applies.
   - The 30-minute figure in Microsoft's tutorial applies to adding a whole group.
   - Fix: gate switch B on each user's sign-in log showing cloud authentication, not on a timer.
   - The design still holds, because "A on, B off" is the safe state.
2. **Creating the Staged Rollout policy is a manual, delegated step.**
   - The draft left this unverified. An application identity cannot create the policy.
   - The pipeline only edits group membership.

## 10. Still unverified

- **Single-tenant broker app.** Microsoft's tutorial registers the app as multitenant. This design uses single tenant, which is narrower. Not confirmed that Okta's built-in Microsoft IdP works with a single-tenant app. Fallback: Okta's generic OIDC (OpenID Connect) IdP pointed at the tenant-specific endpoints. Test in non-prod first.
- **Terraform resource for the IdP.** `okta_idp_social` with type `MICROSOFT`, and the matching type string in the routing rule, were not found in provider documentation on this date.
- **Active Okta sessions.** Okta says rules are evaluated when a user attempts to sign in; it does not say what happens to an existing session.
- **Key-based client authentication.** Whether Okta's Microsoft IdP can use a private key instead of a client secret.
- **Okta System Log event type** for IdP-routed sign-ins.

## 11. Known gotchas

- Legacy authentication (POP3, SMTP) and apps that send a `domain_hint` parameter keep using federation.
- Hybrid join flows that were set up through Okta keep going to Okta until the domain is defederated.
- A service-provider-initiated SAML (Security Assertion Markup Language) request with no user identifier makes Okta prompt for one before an attribute-based rule can route.
- Okta states that routing rules improve the sign-in experience and add no security; app sign-on policies still need setting for the Entra IdP.
- Double MFA prompts are possible if the Okta sign-on policy also demands MFA after the Entra hop.
- Staged Rollout and the broker app are per tenant. The Okta IdP and routing rule point at the prod tenant only.

## Sources

- Microsoft, Migrate Okta federation to Microsoft Entra managed authentication: https://learn.microsoft.com/en-us/entra/identity/enterprise-apps/migrate-okta-federation
- Microsoft, Staged Rollout: https://learn.microsoft.com/entra/identity/hybrid/connect/how-to-connect-staged-rollout
- Microsoft Graph, Create featureRolloutPolicy (permissions): https://learn.microsoft.com/en-us/graph/api/featurerolloutpolicies-post?view=graph-rest-1.0
- Okta, Identity Provider routing rules: https://help.okta.com/oie/en-us/Content/Topics/security/identity_provider_discovery.htm
- Okta, Limitations and workaround for group-based IdP routing rules: https://support.okta.com/help/s/article/limitations-and-potential-workaround-for-group-based-idp-routing-rules-in-okta
- Okta provider, IdP discovery rule arguments (Pulumi mirror of the Terraform provider docs): https://www.pulumi.com/registry/packages/okta/api-docs/policy/ruleidpdiscovery/
- Project doc: `claude/client-redirected-migration.md` (RB-23 draft)
