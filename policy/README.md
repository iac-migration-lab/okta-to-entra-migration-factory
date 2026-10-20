# Policy (Lab Phase 3)

Conftest (OPA, Open Policy Agent) rules in Rego, run by `plan.yml` and `apply.yml` against `terraform show -json` of every plan:

| File | Rule |
|---|---|
| `ca-break-glass.rego` | Every CA (Conditional Access) policy created or updated excludes `bg-ca-exclusion` |
| `ca-report-only.rego` | Every new CA policy starts in report-only |
| `legacy-no-destroy.rego` | Nothing in `entra/legacy/` is destroyed (the pipeline passes the root as `--data`) |

Self-test (pass fixture must pass, fail fixture must trip all three rules): `policy/test.sh`

One plan by hand:
```
terraform -chdir=entra/waves/wave-00 show -json <planfile> > plan.json
conftest test --policy policy/ --data <context.json> plan.json
```
