# SailPoint: Provisioning as Code (Planned)

**Status: not started.** This folder is a placeholder. Run 1 defers it to a later run ([docs/run-1-scope.md](../docs/run-1-scope.md): "SailPoint stand-in, not between Okta and Entra").

## What this folder will be for

In the target design, SailPoint is the **provisioning standard**: it decides who gets an account and which groups they join, from HR (human resources) data, and pushes that to Entra. The Entra code in this repo manages groups but not their members ([entra/platform/README.md](../entra/platform/README.md)); SailPoint is meant to fill in the members.

This folder will prove that SailPoint configuration can be handled like code too: exported to files, reviewed in a pull request, compared with what is live, and imported back.

## Planned contents

| Item | What it is |
|---|---|
| SP-Config JSON files | SailPoint's configuration export format (SP-Config is short for SaaS (software as a service) Configuration, SailPoint's own "as code" API and CLI). Here: one SCIM 2.0 source (SCIM is System for Cross-domain Identity Management, a standard for creating and updating user accounts), its account schema, and its provisioning policy |
| Export, diff and import pipeline | A workflow that exports the live configuration, shows the difference from the files in Git, and imports approved changes |

## Why a mock, not a real tenant

A SailPoint ISC (Identity Security Cloud) tenant is a paid product, outside this lab's $10 monthly budget. The pipeline will run against a **Stoplight Prism mock**: a small local server built from SailPoint's published API description (`sailpoint-oss/api-specs`) that answers like the real API but stores nothing. That proves the pipeline mechanics (export, diff, import, secrets handling) but not SailPoint's behavior.

## Rules that already apply
- Secrets (connector passwords, tokens) are removed on export and injected at import from GitHub environment secrets. They are never committed.
- Pin the SailPoint CLI version (`sail --version`) and record it in the findings log.

## Read next
- [docs/poc-plan-identity-as-code-free-tier.md](../docs/poc-plan-identity-as-code-free-tier.md): the original plan for this part.
- [docs/terraform-provider-analysis-okta-entra-sailpoint.md](../docs/terraform-provider-analysis-okta-entra-sailpoint.md): why SailPoint is handled with SP-Config rather than a Terraform provider.
