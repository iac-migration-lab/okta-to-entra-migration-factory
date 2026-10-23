# Azure Engineer Runbook

## Your role

You own the **ground the pipeline stands on**: the Azure subscription, its budget, the storage account that holds every Terraform state file, and the role assignments that let the pipeline identities reach that storage. If state is lost or locked, no change can be made anywhere, so state protection and recovery are your main jobs.

## What you own

| Item | Details | Where |
|---|---|---|
| Subscription and budget | Lab: Pay-As-You-Go; budget `budget-iac-lab-monthly`, $10, alerts at 50/80/100% | [azure/bootstrap/](../../azure/bootstrap/) |
| Resource group `rg-iac-lab` | West US 3 | Built by CLI (command-line interface); import planned |
| Storage account `stiaclabtfstate02` | Standard LRS (locally redundant storage); storage keys off (Entra ID sign-in only); no public blobs; TLS (Transport Layer Security) 1.2; versioning; 7-day soft delete for blobs and containers | Built by CLI; import planned |
| Container `tfstate-prod` | State: `okta-inventory`, `azure/bootstrap`, prod copy of `entra/legacy`, `entra/platform`, `entra/waves/*` | |
| Container `tfstate-nonprod` | State: nonprod copy of `entra/platform`, `entra/waves/*` | |
| Container `okta-exports` | Nightly Okta user and assignment JSON (personal data) | |
| Storage role assignments for pipeline identities | See table below | [../permission-register.md](../permission-register.md) |

## Who can reach state

| Identity | Role | Scope |
|---|---|---|
| `iac-reader` | Storage Blob Data Contributor | `tfstate-prod`, `okta-exports` |
| `iac-planner` | Storage Blob Data Reader | `tfstate-prod`, `tfstate-nonprod` |
| `iac-applier` | Storage Blob Data Contributor | `tfstate-prod`, `tfstate-nonprod` |
| Owner (lab) | Storage Blob Data Contributor | Whole account (production: PIM-eligible, break-fix only) |

The pipeline identities hold **no** subscription roles. Only you change subscription-level resources, locally, through `azure/bootstrap/`.

## Access you need

| Access | Production target | Lab today |
|---|---|---|
| Subscription | PIM (Privileged Identity Management) eligible Contributor; Owner only to assign roles | Owner (sign-up default) |
| State data | PIM-eligible Storage Blob Data Contributor, break-fix only | Standing Contributor on the account |
| Billing | Cost Management Reader; budget changes through bootstrap | Owner |

Sign in with a browser (security defaults may block the device code flow):
```bash
az config set core.login_experience_v2=off
az login --tenant <tenant ID>
```

## Daily and weekly checks
- **Daily:** nothing, unless an alert fires. Pipeline failures that mention `AuthorizationPermissionMismatch`, `lease`, or `state` come to you.
- **Weekly:** Cost Management → cost so far this month; confirm nothing unexpected is running.
- **Monthly:** list role assignments on the storage account and compare with the permission register:
  ```bash
  SA_ID=$(az storage account show -n stiaclabtfstate02 -g rg-iac-lab --query id -o tsv)
  az role assignment list --scope $SA_ID --include-inherited false --query "[].[principalName,roleDefinitionName,scope]" -o tsv
  for c in tfstate-prod tfstate-nonprod okta-exports; do
    az role assignment list --scope "$SA_ID/blobServices/default/containers/$c" --query "[].[principalName,roleDefinitionName]" -o tsv
  done
  ```

## Create the state file for a new root or wave
Status: Run 1. The planner can only read; it fails with `403 AuthorizationPermissionMismatch` ("failed to lock azure state") on a state file that does not exist yet. Before the first pull request for a new root:
```bash
source lab-tools/env.sh
for c in tfstate-prod tfstate-nonprod; do
  terraform -chdir=entra/waves/wave-NN init -reconfigure -backend-config=container_name=$c
done
```
(`entra/legacy` and `okta-inventory` use `tfstate-prod` only.)

## Stuck state lock
Status: Draft. Terraform locks a state file with a blob lease while it applies. A cancelled or crashed run can leave it locked; the next run fails with "state blob is already locked".
1. Make sure no apply is running: GitHub → Actions → **apply** (and **snapshot** for `okta-inventory`). Never break a lock under a live run.
2. Preferred: unlock with the lock ID from the error message:
   ```bash
   terraform -chdir=<root> init -reconfigure -backend-config=container_name=<container>
   terraform -chdir=<root> force-unlock <lock ID>
   ```
3. If that fails, break the lease directly:
   ```bash
   az storage blob lease break --account-name stiaclabtfstate02 --auth-mode login \
     --container-name <container> --blob-name <key, e.g. entra/platform/terraform.tfstate>
   ```
   UNVERIFIED: `--auth-mode login` on `lease break` in the current Azure CLI.
4. Re-run the failed workflow. Log it.

## Restore a damaged or deleted state file
Status: Draft. Versioning and soft delete keep earlier copies.
1. Stop all pipelines that use the root (tell DevOps; disable the workflows if needed).
2. List versions:
   ```bash
   az storage blob list --account-name stiaclabtfstate02 --auth-mode login --container-name <container> \
     --prefix <key> --include v --query "[].[versionId,properties.lastModified]" -o tsv
   ```
   A deleted blob: `az storage blob undelete --account-name stiaclabtfstate02 --auth-mode login --container-name <container> --name <key>`.
3. Download the good version and push it back through Terraform, so serial numbers stay consistent:
   ```bash
   az storage blob download --account-name stiaclabtfstate02 --auth-mode login --container-name <container> \
     --name <key> --version-id <versionId> --file /tmp/restore.tfstate
   terraform -chdir=<root> state push /tmp/restore.tfstate
   ```
   If Terraform refuses because the serial is older, `state push -force` overrides it. Only use it after confirming with the Entra or Okta engineer which version is right.
4. Plan the root: it should match reality (or show exactly what changed since that version). Re-enable pipelines. Log it.

## Grant a pipeline identity access to a container
Status: Run 1.
```bash
SP=$(az ad sp show --id <appId> --query id -o tsv)
az role assignment create --assignee-object-id $SP --assignee-principal-type ServicePrincipal \
  --role "Storage Blob Data Reader" --scope "$SA_ID/blobServices/default/containers/<container>"
```
Use container scope, never the account or subscription. Add a permission register row the same day. Role changes can take a few minutes to apply.

## Budget alert
Status: Run 1 (budget built; no alert fired yet).
1. Cost Management → **Cost analysis**, group by resource. Find what is costing money.
2. The lab should cost close to nothing: a few cents of storage. Anything else is a mistake or a forgotten resource; delete it or ask its owner.
3. Watch for trials converting to paid: check **Billing** → **Subscriptions** and the Microsoft 365 admin center billing pages for anything you did not start.

## Do not
- Do not turn storage account keys back on. Everything signs in with Entra ID.
- Do not give a pipeline identity a subscription role.
- Do not delete or replace the storage account, or turn off versioning or soft delete.
- Do not break a state lock while a run might be using it.

## Lab 1 lessons
- A new subscription needs `az provider register --namespace Microsoft.Storage --wait` before it can create storage ("SubscriptionNotFound").
- With storage keys off, being subscription Owner is not enough to read blobs; you need a data role.
- In lab 1, a Microsoft 365 trial checkout created a separate tenant with a card on file. Start trials from inside the right tenant.
