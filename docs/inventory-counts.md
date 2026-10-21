# Okta inventory counts

The nightly snapshot (`.github/workflows/snapshot.yml`) writes current counts to this file on branch [`inventory-counts`](https://github.com/iac-migration-lab/okta-to-entra-migration-factory/blob/inventory-counts/docs/inventory-counts.md), not on `main`. `main` requires pull request checks, and the Actions bot cannot push past them. Each count change is a commit on that branch, so its history is the trend.

Last counts kept on `main` (2026-10-17, run 38875055268) are in the Git history of this file.
