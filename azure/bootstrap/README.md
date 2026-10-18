# Azure bootstrap

Azure objects the pipeline depends on. Applied locally by the owner (Azure CLI login), never by the pipeline:
the pipeline identities hold no subscription roles, and this root manages what pipeline state lives in.

| File | Objects |
|---|---|
| `budget.tf` | `budget-iac-lab-monthly` ($10/month, alerts at 50/80/100% actual), imported 2026-10-18 |

Run 2: import `rg-iac-lab` and `stiaclabtfstate02` here too (versioning, soft delete, shared-key off).

```
source lab-tools/env.sh
cd azure/bootstrap && terraform init && terraform plan
```

Providers: hashicorp/azurerm 4.81.0. State: `tfstate-prod/azure/bootstrap/terraform.tfstate`.
