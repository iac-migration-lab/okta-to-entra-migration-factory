# Okta Engineer Runbook

## Your role

You own the **source**: the Okta Identity Engine org that apps are migrating away from. During the migration you keep Okta stable and fully described in code, you cut each wave over by removing Okta assignments, you roll back if needed, and you decommission apps once they are safely in Entra.

You do **not** change Entra. You are consulted on every wave because you know how each Okta app is configured and who uses it.

## What you own

| Item | Where |
|---|---|
| The Okta org (lab: `integrator-2631921`, Identity Engine) | Okta Admin Console |
| The inventory: Terraform describing every Okta configuration object | [okta-inventory/](../../okta-inventory/) |
| The nightly snapshot that checks Okta against the inventory | [.github/workflows/snapshot.yml](../../.github/workflows/snapshot.yml) |
| Service app `iac-okta-reader` (read-only, private key) and its key rotation | Okta → Applications; GitHub environment `okta-read` |
| Service app `iac-okta-cutover` (planned: `okta.apps.manage` only, disabled between waves) | Okta → Applications (Draft: not created yet) |
| Okta side of each wave: freeze, cutover, rollback, decommission | This runbook |

## Access you need

| Access | Production target | Lab today |
|---|---|---|
| Admin Console | Named admin account with a narrow admin role (App Administrator for cutover work), MFA (multi-factor authentication) | Super Administrator (owner) |
| Inventory identity | `iac-okta-reader`: 8 read scopes, custom read-only role on a resource set | Same app, org-wide Read-Only Administrator |
| Cutover identity | `iac-okta-cutover`: `okta.apps.manage`, enabled only during a wave window | Not created; cutover would run as an admin |
| GitHub | Write access to the repo (pull requests), read the `snapshot` runs | Owner |
| API tokens | None. No SSWS (Okta's legacy API token) tokens in production | `iac-run1-seed` SSWS token, to be revoked at the end of run 1 |

## Daily checks (5 minutes)

1. **Snapshot result.** GitHub → Actions → **snapshot** → newest run. Green = Okta matches the inventory. Red = see [When the snapshot goes red](#when-the-snapshot-goes-red). GitHub often starts this 09:17 UTC (Coordinated Universal Time) job a few hours late.
2. **Counts.** If the run committed new counts, open the [`inventory-counts` branch history](https://github.com/iac-migration-lab/okta-to-entra-migration-factory/commits/inventory-counts) and confirm the change was expected (a new hire, a deactivation, a wave cutover).
3. **Okta System Log** for admin changes to apps in an open wave (Reports → System Log, filter `eventType sw "application."`).

## Weekly
- Sign in to the org at least every 90 days: free Integrator orgs deactivate when unused (lab).
- Check the `iac-okta-reader` key age; rotate on the schedule agreed (see [Rotate the reader key](#rotate-the-reader-key)).

## When the snapshot goes red
Status: Run 1.

1. Open the run → **Summary**. It shows the Terraform plan: what differs between Okta and [okta-inventory/](../../okta-inventory/). A step other than "terraform plan" failing is a pipeline problem, not drift: hand it to DevOps ([github-pipeline.md](github-pipeline.md)).
2. Find who made the change: Okta → Reports → **System Log**, filter by the object's name or ID and the time window since the last green run.
3. Decide with the person who made it:
   - **Unapproved change:** undo it in Okta. Re-run the snapshot (Actions → snapshot → **Run workflow**); it should be green.
   - **Approved change:** update the matching `.tf` file in `okta-inventory/` through a pull request so the code matches Okta. Merge; the next snapshot is green.
4. If an app in an open wave changed, tell the Entra engineer: the Entra build may need the same change.
5. Add a findings log entry.

## Freeze an app before its wave
Status: Draft.

From the day a wave is planned until it is decommissioned, its Okta apps are frozen: no attribute, assignment or policy changes except through the wave's change ticket.
1. Note the apps in the change ticket.
2. Tell app admins and the service desk; add a note to each app's description in Okta if your team does that.
3. The nightly snapshot is your guard: any change to a frozen app turns it red.

## Export assignments before a cutover
Status: Draft. The nightly snapshot already uploads every app's group assignments to Azure Blob (`okta-exports/<date>/<run id>/`). Before a cutover, take a fresh copy so a rollback has exact data:

1. Actions → **snapshot** → **Run workflow**. Wait for green.
2. Note the run ID in the change ticket. That run's export in Blob is your rollback source.
3. Also record, per app, the group IDs from the inventory file (`okta-inventory/app-<name>.tf`, `okta_app_group_assignments`). That is the second copy, and it is in Git.

## Cut over a wave
Status: Draft (Lab Phase 4). Only after the Entra engineer has signed off sign-in tests and the change window is open.

1. **Enable** `iac-okta-cutover` (Applications → the app → **Activate**). Record the time.
2. For each app in the wave, remove each group assignment. With the Admin Console: Applications → app → **Assignments** → remove each group. With the API (Application Programming Interface), as the cutover identity:
   ```bash
   # list, then remove, each group assigned to the app
   curl -s -H "Authorization: Bearer $TOKEN" "$OKTA_ORG_URL/api/v1/apps/<appId>/groups" | jq -r '.[].id'
   curl -s -X DELETE -H "Authorization: Bearer $TOKEN" "$OKTA_ORG_URL/api/v1/apps/<appId>/groups/<groupId>"
   ```
   Removing the assignment removes the app tile and stops Okta sign-in for those users. The app itself stays, so rollback is quick.
3. **Deactivate** `iac-okta-cutover` again.
4. Update the inventory to match: in each app's `okta-inventory/app-<name>.tf`, remove the groups from `okta_app_group_assignments` by pull request. Until it merges, the snapshot is red for exactly these changes; note that in the change ticket so nobody "fixes" it.
5. Tell the Entra engineer and the service desk that the validation window has started.

## Roll back a wave
Status: Draft. Target: under 15 minutes per app; time it in the Lab Phase 4 drill.

1. Enable `iac-okta-cutover`.
2. Re-add each group from the pre-cutover export:
   ```bash
   curl -s -X PUT -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
     -d '{}' "$OKTA_ORG_URL/api/v1/apps/<appId>/groups/<groupId>"
   ```
3. If the app's service provider was re-pointed to Entra, the app owner points it back to Okta's metadata (keep Okta's metadata URL in the change ticket).
4. Deactivate `iac-okta-cutover`. Revert the inventory pull request. Log the rollback and the time it took.

## Decommission an app
Status: Draft. Only after the agreed quiet period with no rollback (suggested 30 days).
1. Deactivate the app in Okta (Applications → app → **Deactivate**). Wait one more snapshot cycle.
2. Delete the app. Remove its file and import block from `okta-inventory/` by pull request. Remove it from state with a `removed` block, so Terraform forgets it without trying to delete it.
3. Log it; the app is now Entra only.

## Rotate the reader key
Status: Draft.
1. Okta → Applications → `iac-okta-reader` → **General** → **Public keys** → **Add key** → generate. Save the new private key (PEM) to the vault.
2. Update GitHub: environment `okta-read` → secret `OKTA_PRIVATE_KEY` (new PEM) and variable `OKTA_KEY_ID` (new key ID). Command line:
   ```bash
   gh secret set OKTA_PRIVATE_KEY --env okta-read < new-key.pem
   gh variable set OKTA_KEY_ID --env okta-read --body <new kid>
   ```
3. Run the snapshot by hand; it must be green.
4. Deactivate, then delete, the old key in Okta. Update the permission register row.

## Onboard a new Okta object into the inventory
Status: Run 1. See [okta-inventory/README.md § Adding an object](../../okta-inventory/README.md#adding-an-object-to-the-inventory): import block, generate config, tidy, plan until the only action is `import`.

## Checks before any client engagement
- The org must be **Identity Engine**: `curl -s https://<org>.okta.com/.well-known/okta-organization` returns `"pipeline": "idx"`. Classic orgs upgrade first ([../okta-identity-engine-decision.md](../okta-identity-engine-decision.md)).

## Do not
- Do not run `terraform apply` in `okta-inventory/` except to record imports. The inventory never changes Okta.
- Do not leave `iac-okta-cutover` active outside a wave window.
- Do not commit users, memberships or exports to Git. They go to Blob only.
- Do not create SSWS tokens for automation.

## Lab 1 lessons
- New orgs: the built-in Okta Dashboard authentication policy can require two factors, so new users without an enrolled factor cannot sign in. Check it before user testing.
- The reader needs `okta.networkZones.read` (an eighth scope) to import zones.
- Catalog apps such as Slack show drift on fields the provider sets for preconfigured apps; tidy them out of the code.
