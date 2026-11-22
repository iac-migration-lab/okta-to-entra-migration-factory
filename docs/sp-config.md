# SP-Config: relevant capabilities

Status: working reference, checked November 21, 2026 against SailPoint's SaaS Configuration documentation. Items carried over from the September 30 provider analysis and not re-checked are marked UNVERIFIED.

SP-Config (SaaS Configuration) is SailPoint's own export and import interface for Identity Security Cloud (ISC) configuration. In this program it is how SailPoint becomes "configuration as code": same Git repository, same pull request (PR) review, same change gate as Terraform, with a different tool underneath.

## 1. Role in this program

- **Position:** Terraform manages Okta (read) and Entra ID (write). SailPoint is managed through SP-Config, not Terraform. There is no official Terraform provider for ISC.
- **Scope:** sources and provisioning for the roughly 70 SCIM (System for Cross-domain Identity Management) applications that move from Okta provisioning to SailPoint. Not the whole ISC tenant.
- **Out of scope:** roles and access profiles. SP-Config can export them but not import them, so they stay portal-managed and are snapshotted for drift only.

## 2. What it can manage

### Export and import (can be promoted through the pipeline)

| Object | Type key | Relevance here |
|---|---|---|
| Sources (standard sources only) | `SOURCE` | Core: each migrated SCIM app becomes a source |
| Transforms | `TRANSFORM` | Attribute shaping for provisioning |
| Identity Profiles | `IDENTITY_PROFILE` | Only if a migrated app needs a profile change |
| Rules | `RULE` | Exported and imported as-is; cannot be edited in transit (signed) |
| Connector Rules | `CONNECTOR_RULE` | For Web Services connectors |
| Identity Object Configuration | `IDENTITY_OBJECT_CONFIG` | Unlikely to change in this program |
| Event Trigger Subscriptions | `TRIGGER_SUBSCRIPTION` | Only if provisioning events are consumed elsewhere |

### Export only (snapshot for drift; change in the portal or Configuration Hub)

Access Profiles, Roles, Workflows, Lifecycle States, Form Definitions, Governance Groups, Password Policies, Password Sync Groups, Segments, Separation of Duties Policies, Service Desk Integrations, Notification Templates, Tags, Campaign Filters, Access Request Configuration, Attribute Sync Source Configuration, Authentication Configuration, Public Identities Configuration.

## 3. Capabilities that matter to the pipeline

| Capability | Detail | How we use it |
|---|---|---|
| Filtered export | Payload takes `includeTypes`, `excludeTypes`, and `objectOptions` with `includedIds` / `includedNames` per type | Export only the sources in a wave |
| Import preview | `preview=true` on the import call reports what would happen and any reference errors, without changing the tenant | The equivalent of `terraform plan`; attach the result to the PR |
| Automatic backup | An import first exports all existing supported objects; the result returns the backup as `exportJobId` | Rollback point for every import; do not set `excludeBackup` |
| Asynchronous jobs | Start, poll status, download result | Pipeline job polls until complete |
| Object list | Lists what the tenant supports | Check before relying on a type |

## 4. Interface

All endpoints are under `/beta/sp-config/`.

| Action | Call |
|---|---|
| Start export | `POST /beta/sp-config/export` |
| Export status | `GET /beta/sp-config/export/{id}` |
| Download export | `GET /beta/sp-config/export/{id}/download` |
| Start import | `POST /beta/sp-config/import` (multipart, file field `data`) |
| Import status | `GET /beta/sp-config/import/{id}` |
| Download import result | `GET /beta/sp-config/import/{id}/download` |
| List supported objects | `GET /beta/sp-config/config-objects` |

Export payload example:

```json
{
  "description": "Wave 03 sources - nightly export",
  "includeTypes": ["SOURCE"],
  "objectOptions": {
    "SOURCE": { "includedNames": ["Claims Portal SCIM"] }
  }
}
```

Command examples (UNVERIFIED: tenant host pattern; confirm for the client's tenant):

```bash
# Export
curl -s -X POST "https://<tenant>.api.identitynow.com/beta/sp-config/export" \
  -H "Authorization: Bearer $SP_TOKEN" -H "Content-Type: application/json" \
  -d @export-wave-03.json

# Preview an import (no change to the tenant)
curl -s -X POST "https://<tenant>.api.identitynow.com/beta/sp-config/import?preview=true" \
  -H "Authorization: Bearer $SP_TOKEN" -F "data=@sailpoint/sources/wave-03.json"
```

SailPoint CLI (command line interface) equivalents, UNVERIFIED on this date: `sail spconfig export` and `sail spconfig import`.

## 5. Access (least privilege)

| Grant | What the documentation requires | Narrow version | Blast radius if broader |
|---|---|---|---|
| Export identity | Tenant administrator (`ORG_ADMIN`) as a prerequisite; scope `sp:config:read` | Dedicated API client or personal access token with `sp:config:read` only | Read of tenant configuration |
| Import identity | `ORG_ADMIN`; scope `sp:config:manage` | Separate identity with `sp:config:manage`, usable only from the protected production environment | Rewrite of sources that provision into production Active Directory |
| Source credentials | Not exported by SP-Config | Injected at import from the pipeline's secret store; never in Git | Credential exposure in the repository |

- **Flag:** the `ORG_ADMIN` prerequisite is broad and is SailPoint's requirement, not our choice. The control we add is the token scope and the separation of the read and manage identities.
- **Cost of going narrow:** two identities to create and rotate instead of one.

## 6. Limits to plan around

- **Secrets are stripped.** Source passwords, secret tokens and other sensitive data are not exported and must be re-added after import.
- **Silent skips.** Unsupported object types in an import payload are skipped with no error, and the job still reports `COMPLETE`. The pipeline must compare what was sent with what was applied.
- **Non-employee sources** cannot be imported; deploying one from a backup creates a standard source.
- **Rules are signed** (`jwsHeader`, `jwsSignature`) and cannot be modified during migration.
- **Filters apply to importable types only.** `includedIds` and `includedNames` do not work for export-only types.
- **Long jobs can expire.**
- **Beta API.** Every endpoint is under `/beta/`.
- **No state file.** There is no stored record of intended configuration; drift detection is export, then diff against Git.

## 7. Pipeline shape

1. PR changes the source JSON under `sailpoint/`.
2. Pipeline runs an import with `preview=true` and posts the result on the PR.
3. Review, then the ServiceNow change gate (production only).
4. Import to non-production, then production. Credentials injected at this step.
5. Pipeline records the `exportJobId` backup and compares sent objects with applied objects.
6. Nightly: export, diff against Git, open an issue on any difference.

## 8. Corrections and open points

- **Correction to the September 30 analysis:** it said SP-Config "has no plan step". The import call has a preview mode, which serves that purpose.
- **UNVERIFIED:** whether a source's provisioning policies travel inside the `SOURCE` object or need separate handling. Test with one real source before sizing.
- **Open with the client:** whether Configuration Hub is enabled, whether a non-production ISC tenant mirrors production, and which connector types the migrating apps will use.

## Sources

- SailPoint, SaaS Configuration (SP-Config): https://developer.sailpoint.com/docs/extensibility/configuration-management/saas-configuration/
- SailPoint, Configuration Hub: https://developer.sailpoint.com/docs/extensibility/configuration-management/configuration-hub/
- In this folder: `terraform-provider-analysis-okta-entra-sailpoint.md`
