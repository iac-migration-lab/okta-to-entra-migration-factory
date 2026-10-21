# Decision: Okta Identity Engine Only

Decided 2026-10-21 (Run 1). Applies to the lab and to the client build.

## Decision
- The source Okta org is **Okta Identity Engine (OIE)**. The method, the inventory, the translation layer and the runbook are built for OIE only.
- **Okta Classic Engine is out of scope.** A Classic org must be upgraded to OIE before the migration starts. That upgrade is a client prerequisite with its own plan; it is not part of this method or its estimate.
- The lab org `integrator-2631921` is OIE (checked 2026-10-21, see below).

## Why
- The objects that drive the Conditional Access (CA) translation exist only in OIE: authentication policies (`okta_app_signon_policy`), authenticators (`okta_authenticator`) and profile enrollment policies. The okta provider marks each "only available as a part of the Identity Engine".
- On a Classic org the inventory would miss those policies, and the translation layer would have less to read from (provider analysis section 2.3).
- One engine means one inventory shape, one mapping catalog and one set of tests. Supporting both would double that work for an engine Okta is moving customers off.

## How to check an org
```bash
curl -s https://<org>.okta.com/.well-known/okta-organization | python3 -m json.tool
```
- `"pipeline": "idx"` means Identity Engine. Lab org result on 2026-10-21: `"pipeline": "idx"`.
- `"pipeline": "v1"` means Classic. UNVERIFIED: not seen on a real Classic org in this lab.
- Second check: the Admin Console has **Security > Authentication Policies** only on OIE.

Run the check at client intake, before sizing, and record the result in the findings log.

## What OIE means for the inventory and the translation

| OIE object (Admin Console name) | Terraform resource (okta 7.0.0) | OIE only? | Entra target |
|---|---|---|---|
| Global session policy and rules | `okta_policy_signon`, `okta_policy_rule_signon` | No (same resource, OIE meaning) | CA session controls (sign-in frequency, persistent browser) |
| Authentication policy (app sign-on policy) and rules | `okta_app_signon_policy`, `okta_app_signon_policy_rule` | **Yes** | CA policies per app; authentication strengths |
| Authenticators | `okta_authenticator` | **Yes** | Authentication methods policy |
| Authenticator enrollment policy | `okta_policy_mfa` with `is_oie = true`, `okta_policy_rule_mfa` | OIE mode of a shared resource | Authentication methods registration (UNVERIFIED: registration campaign vs CA "register security info") |
| Profile enrollment policy | `okta_policy_profile_enrollment` | **Yes** | No direct equivalent for workforce users; joiners come from HR or SailPoint provisioning |
| Password policy | `okta_policy_password` | No | Entra password protection and SSPR (self-service password reset) settings |
| Network zone | `okta_network_zone` | No | Named location |

**Naming trap:** the provider still calls `okta_policy_signon` a "Sign On Policy" (the Classic name). In an OIE org that resource is the **global session policy**. Classic "Okta sign-on policy" semantics do not apply.

**Not used (Classic-era):** `okta_factor` (factor activation; replaced by `okta_authenticator`), and `okta_policy_mfa` without `is_oie` (Classic MFA enrollment policy built on factors).

## Lab status and follow-ups
- Run 1 inventory already reads the OIE objects the seed created: global session policy `iac-gsp-staff`, authentication policy `iac-authn-saml-apps`, password policy `iac-pwd-staff`.
- **Gap, run 2:** the inventory does not import authenticators or the authenticator enrollment policy yet. Add `okta_authenticator` and `okta_policy_mfa` (`is_oie = true`) import blocks. The reader may need an extra read scope for authenticators (UNVERIFIED: `okta.authenticators.read`). Register the scope when granted.
- Run 1 lessons that were OIE behavior: the password policy recovery block and the built-in Okta Dashboard authentication policy (findings 2026-10-16, Lab Phase 1).
