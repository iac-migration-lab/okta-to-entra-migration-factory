# Build by Hand

Every step to build this lab yourself, in order, with no AI assistant: Okta read as code, Entra written as code, and a GitHub pipeline between them. Each part says what you do, how to check it worked, and what went wrong in lab 1.

**Who this is for:** someone comfortable pasting commands into a Mac terminal and clicking through admin portals. You do not write Terraform from scratch; the code is in the repo.

**Moving to new accounts?** Do [porting-guide.md](porting-guide.md) first. It lists every value to replace. This guide uses placeholders in `<angle brackets>` for those values.

**Conventions**
- Run commands from the repo root unless a step says otherwise. Start every terminal session with `source lab-tools/env.sh`.
- `UNVERIFIED:` marks a portal label or behavior not re-checked for this guide. Portals change; look for the nearest match.
- Secrets live only in `~/.okta-lab/` (folder mode 700, files 600) and a password manager. Never in the repo, which is public.
- After every grant (role, permission, scope, token, secret, consent), add a row to `docs/permission-register.md`. After every step, add an entry to `docs/findings-log.md` using the template at its top.

## Contents
1. Accounts
2. Tools
3. Repo
4. Okta: seed the source org
5. Okta: read-only identity
6. Azure: state storage and the snapshot identity
7. Okta: inventory as code and the nightly snapshot
8. Entra: break-glass, licenses, brownfield
9. Entra: import the brownfield (`entra/legacy`)
10. Pipeline identities
11. GitHub settings
12. First PR: build platform and wave-00 through the pipeline
13. Test users and sign-in tests
14. Pipeline exit tests and drift
15. Daily operation
16. Troubleshooting (lab 1 lessons)

Planned but not yet run in lab 1: the cutover wave and rollback drill (Lab Phase 4). See [build-phases.md](build-phases.md).

---

## 1. Accounts

| Account | Notes |
|---|---|
| Dedicated mailbox (for example Outlook.com) | Use it for every Microsoft sign-up. Keep it away from any work tenant. |
| Okta Integrator Free Plan org | https://developer.okta.com/signup/. Okta rejects free email providers; use an address on a domain you control that is **not** tied to a production Microsoft tenant. Sign in at least every 90 days or the org deactivates. |
| Azure account (Pay-As-You-Go) | Creates an Entra tenant ("Default Directory"); that tenant is the lab tenant. No spending limit: add a budget alert on day one. |
| GitHub organization (free) and a **public** repo | Free private repos have no environment reviewers or environment secrets. |
| Password manager | For every password and private key you create. |

**Check the Okta engine now.** The method supports Okta Identity Engine only ([okta-identity-engine-decision.md](okta-identity-engine-decision.md)):

```bash
curl -s https://<okta-org>.okta.com/.well-known/okta-organization | python3 -m json.tool
```
`"pipeline": "idx"` = Identity Engine, continue. Anything else, stop.

**First-day settings**
1. Turn on MFA (multi-factor authentication) for the mailbox and the Okta admin.
2. Entra admin center (https://entra.microsoft.com) → **Entra ID** → **Overview** → **Properties**: rename the tenant (lab 1: `IaC Migration Lab`).
3. Azure portal → **Cost Management** → **Budgets** → **Add**: monthly, $10, email alerts at 50%, 80%, 100%. (Lab 1 later imported it into `azure/bootstrap/`.)

---

## 2. Tools

Apple Silicon Mac. Paste the install block from [tool-install.md](tool-install.md); it checksum-verifies each download and puts it in `lab-tools/` (git-ignored). Also install the GitHub CLI (command-line interface) and `jq`:

```bash
brew install gh jq
gh auth login
```

Check:
```bash
source lab-tools/env.sh
terraform -version          # 1.16.4
conftest --version          # 0.71.0
az version --query '"azure-cli"' -o tsv
gh --version && jq --version
```

Provider versions are pinned in each `versions.tf`: `okta/okta` 7.0.0, `hashicorp/azuread` 3.10.0, `microsoft/msgraph` 0.5.0, `hashicorp/azurerm` 4.81.0.

---

## 3. Repo

```bash
mkdir -p ~/Projects && cd ~/Projects
git clone https://github.com/<github-org>/<repo>.git okta-to-entra-migration
cd okta-to-entra-migration
mkdir -p ~/.okta-lab && chmod 700 ~/.okta-lab
```

The tool install block expects the repo at `~/Projects/okta-to-entra-migration`; change the path in the block if you use another.

---

## 4. Okta: seed the source org

Lab only. A real migration reads the client's existing org instead. The seed builds what [okta-seed-spec.md](okta-seed-spec.md) describes: 8 users, groups `IT`, `CustServ`, `Finance`, 4 custom SAML apps, 1 OIDC app, 1 Slack gallery app, a network zone, a password policy, a global session policy, an authentication policy and a custom authorization server.

1. **Seeding token (lab shortcut).** Admin Console (`https://<okta-org>-admin.okta.com`) → **Security** → **API** → **Tokens** → **Create token**, name `iac-run1-seed`. Save it:
   ```bash
   pbpaste > ~/.okta-lab/ssws-token && chmod 600 ~/.okta-lab/ssws-token
   ```
   Register it (production verdict: Not OK; revoke at the end of the run).
2. **Dry run, then apply.** Type one command per line (a multi-line paste split an `export` in lab 1):
   ```bash
   export OKTA_ORG_URL=https://<okta-org>.okta.com
   export OKTA_API_TOKEN_FILE=~/.okta-lab/ssws-token
   okta-inventory/seed/seed-okta-org.sh            # dry run: prints planned writes, 0 failures expected
   okta-inventory/seed/seed-okta-org.sh --apply    # asks once for the shared test-user password
   ```
   If the password prompt went wrong, set it again: `okta-inventory/seed/reset-seed-passwords.sh` (asks twice).
3. **Smoke test.** In a private window, sign in to `https://<okta-org>.okta.com` as `ada.reyes@<login-domain>`. Open each SAML tile; the test site shows the attributes it received. The OIDC app has no tile (by design).

**Lab 1 lessons built into the script:** Identity Engine needs the full recovery block on the password policy; system catch-all rules accept only `conditions: null`; the built-in Okta Dashboard catch-all is set to password only so new users without a second factor can sign in.

---

## 5. Okta: read-only identity

`iac-okta-reader` reads Okta for the inventory. It signs in with a private key, never a password or API token.

1. Admin Console → **Applications** → **Applications** → **Create App Integration** → **API Services** → name `iac-okta-reader` → **Save**.
2. **General** tab → **Client Credentials** → **Edit** → **Public key / Private key** → **Add key** → **Generate new key**. Copy the private key in PEM format **now** (it is shown once) and save it:
   ```bash
   pbpaste > ~/.okta-lab/iac-okta-reader.pem && chmod 600 ~/.okta-lab/iac-okta-reader.pem
   ```
   Note the key ID (`kid`). **Save**. UNVERIFIED: the PEM tab label in the key dialog.
3. If **Require Demonstrating Proof of Possession (DPoP) header in token requests** is ticked, untick it; the scripts and provider here do not send DPoP. UNVERIFIED: whether new orgs tick it by default.
4. **Okta API Scopes** tab → **Grant** each: `okta.apps.read`, `okta.users.read`, `okta.groups.read`, `okta.policies.read`, `okta.authorizationServers.read`, `okta.idps.read`, `okta.schemas.read`, `okta.networkZones.read`.
5. **Admin roles** tab → **Edit assignments** → role **Read-Only Administrator** → **Save changes**.
6. Register rows: the app, its scopes, its role.
7. **Check** (counts only, and a write attempt that must be refused):
   ```bash
   export OKTA_ORG_URL=https://<okta-org>.okta.com
   export OKTA_CLIENT_ID=<client id from the General tab>
   export OKTA_KEY_ID=<kid>
   export OKTA_PRIVATE_KEY_FILE=~/.okta-lab/iac-okta-reader.pem
   okta-inventory/verify-reader.sh
   ```
   Expect counts per object type and "Write (create group): HTTP 403". Built-in Okta apps are not visible to this identity; that is normal.

---

## 6. Azure: state storage and the snapshot identity

1. **Sign in.** Security defaults may block device-code sign-in; use the browser flow in a private window:
   ```bash
   az config set core.login_experience_v2=off
   az login --tenant <tenant-id>
   az account set --subscription <subscription-id>
   ```
2. **Register the storage provider** (a new subscription fails with "SubscriptionNotFound" without it):
   ```bash
   az provider register --namespace Microsoft.Storage --wait
   ```
3. **Storage account** (name globally unique: check first):
   ```bash
   RG=rg-iac-lab; SA=<storage-account>; LOC=westus3
   az storage account check-name --name $SA
   az group create -n $RG -l $LOC
   az storage account create -n $SA -g $RG -l $LOC --sku Standard_LRS \
     --allow-shared-key-access false --allow-blob-public-access false --min-tls-version TLS1_2
   az storage account blob-service-properties update -n $SA -g $RG --enable-versioning true \
     --enable-delete-retention true --delete-retention-days 7 \
     --enable-container-delete-retention true --container-delete-retention-days 7
   ME=$(az ad signed-in-user show --query id -o tsv)
   SCOPE_SA=$(az storage account show -n $SA -g $RG --query id -o tsv)
   az role assignment create --assignee-object-id $ME --assignee-principal-type User \
     --role "Storage Blob Data Contributor" --scope $SCOPE_SA
   for c in tfstate-prod tfstate-nonprod okta-exports; do az storage container create -n $c --account-name $SA --auth-mode login; done
   ```
   The role can take a few minutes to apply; retry the container step if it says "not authorized". Register your role row.
4. **GitHub subject prefix** (needed for every federated credential):
   ```bash
   O=<github-org>; R=<repo>
   gh api repos/$O/$R/actions/oidc/customization/sub     # expect use_immutable_subject: true
   PREFIX="repo:$O@$(gh api orgs/$O --jq .id)/$R@$(gh api repos/$O/$R --jq .id)"
   echo $PREFIX
   ```
   If `use_immutable_subject` is false, the prefix is `repo:<org>/<repo>` instead.
5. **`iac-reader`** app registration, no client secret, with two federated credentials:
   ```bash
   fic() { az ad app federated-credential create --id "$1" --parameters \
     "{\"name\":\"$2\",\"issuer\":\"https://token.actions.githubusercontent.com\",\"subject\":\"$PREFIX:$3\",\"audiences\":[\"api://AzureADTokenExchange\"]}"; }
   READER=$(az ad app create --display-name iac-reader --query appId -o tsv)
   az ad sp create --id $READER
   fic $READER github-okta-read environment:okta-read
   fic $READER github-main ref:refs/heads/main
   READER_SP=$(az ad sp show --id $READER --query id -o tsv)
   cscope() { echo "$SCOPE_SA/blobServices/default/containers/$1"; }
   for c in tfstate-prod okta-exports; do
     az role assignment create --assignee-object-id $READER_SP --assignee-principal-type ServicePrincipal \
       --role "Storage Blob Data Contributor" --scope "$(cscope $c)"
   done
   ```
   Register: the app, both credentials, both roles.

Keep this terminal open (or save `PREFIX`, `SCOPE_SA`, the app IDs) for parts 10 and 11.

---

## 7. Okta: inventory as code and the nightly snapshot

### 7.1 Point the import blocks at your org
`okta-inventory/imports.tf` holds one import block per object. On a new org, replace each `id` with yours. List them with the seeding token (read calls only):

```bash
api() { curl -s -H "Authorization: SSWS $(cat ~/.okta-lab/ssws-token)" -H "Accept: application/json" "$OKTA_ORG_URL/api/v1/$1"; }
api groups | jq -r '.[] | "\(.id)  \(.profile.name)"'
api apps | jq -r '.[] | "\(.id)  \(.label)"'
api zones | jq -r '.[] | "\(.id)  \(.name)"'
for t in PASSWORD OKTA_SIGN_ON ACCESS_POLICY; do api "policies?type=$t" | jq -r --arg t $t '.[] | "\($t)  \(.id)  \(.name)"'; done
api "policies/<policy-id>/rules" | jq -r '.[] | "\(.id)  \(.name)"'
api authorizationServers | jq -r '.[] | "\(.id)  \(.name)"'
for x in scopes claims policies; do api "authorizationServers/<auth-server-id>/$x" | jq -r --arg x $x '.[] | "\($x)  \(.id)  \(.name)"'; done
```

Import ID formats (okta 7.0.0), from `imports.tf`:

| Resource | ID format |
|---|---|
| `okta_group`, `okta_app_saml`, `okta_app_oauth`, `okta_network_zone`, `okta_auth_server`, `okta_policy_*`, `okta_app_signon_policy` | `<id>` |
| `okta_app_group_assignments` | `<app id>` |
| Policy rules, auth server scope / claim / policy | `<parent id>/<child id>` |
| `okta_auth_server_policy_rule` | `<auth server id>/<policy id>/<rule id>` |

Also set `default_app_signon_policy_id` in `okta-inventory/groups.tf` to your org's built-in default authentication policy (`ACCESS_POLICY` named "Default Policy").

Policy names map to Identity Engine objects: `PASSWORD` = password policy, `OKTA_SIGN_ON` = global session policy, `ACCESS_POLICY` = authentication policy.

### 7.2 Plan until clean (local state first)
```bash
export OKTA_API_PRIVATE_KEY=~/.okta-lab/iac-okta-reader.pem
export OKTA_API_PRIVATE_KEY_ID=<kid>
mv okta-inventory/backend.tf /tmp/okta-backend.tf.hold     # local state for the first import
terraform -chdir=okta-inventory init
terraform -chdir=okta-inventory plan
```
- New org, same seed: the checked-in `*.tf` should match; fix any differences the plan shows.
- Objects not in the code yet: remove their resource blocks, keep the import blocks, and run `terraform -chdir=okta-inventory plan -generate-config-out=generated.tf`. Then tidy `generated.tf` into the per-type files: replace literal IDs with references, delete `= null` lines, delete `preconfigured_app` and `app_links_json` on custom SAML apps, use `jsonencode()` for policy rule constraints. Lab 1's full list of generator errors is in the findings log ("Okta inventory imported and normalized").
- When the plan shows only imports: `terraform -chdir=okta-inventory apply` (import only; the reader cannot write to Okta). Then `terraform -chdir=okta-inventory plan -detailed-exitcode` must exit 0 ("No changes").

### 7.3 Move state to Azure
```bash
mv /tmp/okta-backend.tf.hold okta-inventory/backend.tf     # storage account name already replaced
terraform -chdir=okta-inventory init -migrate-state
terraform -chdir=okta-inventory plan -detailed-exitcode    # still exit 0
rm -f okta-inventory/terraform.tfstate okta-inventory/terraform.tfstate.backup
```

### 7.4 GitHub environment `okta-read` and the snapshot
```bash
gh api -X PUT repos/$O/$R/environments/okta-read
gh variable set AZURE_CLIENT_ID --env okta-read --body $READER
gh variable set AZURE_TENANT_ID --env okta-read --body <tenant-id>
gh variable set OKTA_CLIENT_ID  --env okta-read --body <okta reader client id>
gh variable set OKTA_KEY_ID     --env okta-read --body <kid>
gh secret set OKTA_PRIVATE_KEY  --env okta-read < ~/.okta-lab/iac-okta-reader.pem
gh workflow run snapshot.yml && sleep 10 && gh run watch "$(gh run list --workflow snapshot.yml -L 1 --json databaseId --jq '.[0].databaseId')"
```
Green = Okta matches the code. It also commits `docs/inventory-counts.md` to the branch `inventory-counts` (created on the first run; `main` is protected and the bot cannot push there) and uploads user JSON to the `okta-exports` container (never Git). Register the secret.

### 7.5 Prove drift detection
Change the Finance group description in the Admin Console, run the snapshot again: it must fail at "Fail on drift" and show the change. Put the description back; the next run is green. Exit: green two nights running.

---

## 8. Entra: break-glass, licenses, brownfield

1. **Admin and break-glass accounts** (keep the passwords in the password manager):
   ```bash
   D=<tenant-domain>.onmicrosoft.com
   az ad user create --display-name "Break Glass 01" --user-principal-name bg-admin-01@$D --password '<long passphrase>'
   az ad user create --display-name "IaC Lab Admin" --user-principal-name iac-lab-admin@$D --password '<password>'
   ```
   Entra admin center → **Roles & admins** → **Global Administrator** → **Add assignments**: add both. Sign in once as each in a private window, set a new password, and register an authenticator (and a FIDO2 key for break-glass if you have one). Register the roles.
2. **Exclusion group:**
   ```bash
   BG=$(az ad group create --display-name bg-ca-exclusion --mail-nickname bg-ca-exclusion --query id -o tsv)
   az ad group member add --group $BG --member-id $(az ad user show --id bg-admin-01@$D --query id -o tsv)
   az ad group member add --group $BG --member-id $(az ad signed-in-user show --query id -o tsv)
   echo $BG    # put this ID in the four files listed in porting-guide.md section 3.2, then run policy/test.sh
   ```
3. **Entra ID P2 trial:** sign in as `iac-lab-admin` in a clean browser profile → Entra admin center → **Billing** → **Licenses** → **All products** → **Try / Buy** → **Microsoft Entra ID P2** → **Free trial** → **Activate**. Do not use Microsoft 365 Marketplace checkout; in lab 1 it created a separate tenant and a paid-converting subscription. Note the end date: Lab Phases 2 to 4 must finish before it.
4. **Turn off security defaults** (custom CA policies need this): Entra admin center → **Entra ID** → **Overview** → **Properties** → **Manage security defaults** → **Disabled**. UNVERIFIED: menu path.
5. **Brownfield objects by hand** (simulates an existing tenant). Create in the Entra admin center:

   | Object | Name | Settings |
   |---|---|---|
   | Named location | `iac-legacy-nl-office` | IP range `203.0.113.0/24`, trusted |
   | Authentication strength | `iac-authenticator-or-fido2` | FIDO2, or password + Microsoft Authenticator push |
   | Security group | `iac-legacy-finance-users` | |
   | Security group | `iac-legacy-privileged-admins` | member `iac-lab-admin` |
   | CA policy | `LAB-CA01 - All apps - Require MFA - Admins - Any location` | On; All users; All resources; grant MFA |
   | CA policy | `LAB-CA02 - All apps - Block - All users - Legacy auth` | On; All users; All resources; client apps: legacy; block |
   | CA policy | `LAB-CA03 - Office 365 - Auth strength - Finance users - Outside office` | Report-only; Finance group; Office 365; exclude the named location; require the authentication strength |
   | Enterprise app | `iac-legacy-zoom` | Gallery app Zoom, no SSO |

   **Every CA policy excludes the group `bg-ca-exclusion` and your owner account.** Read each policy back afterwards (two of three missed it in lab 1):
   ```bash
   az rest --url "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies" \
     --query "value[].{name:displayName, state:state, excludedGroups:conditions.users.excludeGroups}" -o json
   ```

---

## 9. Entra: import the brownfield (`entra/legacy`)

Your Azure CLI login cannot read authentication strengths (HTTP 403), so local plans of `entra/legacy` run as `iac-reader` with a short-lived certificate.

1. **Graph read permissions for `iac-reader`**, consented from break-glass (sign in as `bg-admin-01` for the consent step only):
   ```bash
   GRAPH=00000003-0000-0000-c000-000000000000
   role_id() { az ad sp show --id $GRAPH --query "appRoles[?value=='$1'].id | [0]" -o tsv; }
   grant() { local app=$1; shift; for p in "$@"; do az ad app permission add --id $app --api $GRAPH --api-permissions "$(role_id $p)=Role"; done; }
   grant $READER Directory.Read.All Policy.Read.All
   az login --tenant <tenant-id>      # as bg-admin-01@<tenant-domain>
   az ad app permission admin-consent --id $READER
   az login --tenant <tenant-id>      # back to your own account
   ```
2. **Local certificate for `iac-reader`** (lab shortcut, 60 days; register it):
   ```bash
   cd ~/.okta-lab
   openssl req -x509 -newkey rsa:2048 -nodes -days 60 -subj "/CN=iac-reader-local" \
     -keyout iac-reader-local.key.pem -out iac-reader-local.cert.pem
   openssl pkcs12 -export -inkey iac-reader-local.key.pem -in iac-reader-local.cert.pem -out iac-reader-local.pfx -passout pass:'<pfx password>'
   chmod 600 iac-reader-local.*
   az ad app credential reset --id $READER --cert @iac-reader-local.cert.pem --append
   cat > entra-legacy-env.sh <<EOF
   export ARM_TENANT_ID=<tenant-id>
   export ARM_CLIENT_ID=$READER
   export ARM_CLIENT_CERTIFICATE_PATH=$HOME/.okta-lab/iac-reader-local.pfx
   export ARM_CLIENT_CERTIFICATE_PASSWORD='<pfx password>'
   EOF
   chmod 600 entra-legacy-env.sh; cd -
   ```
3. **Point the import blocks at your objects.** List IDs and put them in `entra/legacy/imports.tf`; set `bg_ca_exclusion_group_id` and `owner_user_id` in `entra/legacy/locals.tf`, and the `iac-lab-admin` ID in `entra/legacy/groups.tf`:
   ```bash
   az rest --url https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies --query "value[].[id,displayName]" -o tsv
   az rest --url https://graph.microsoft.com/v1.0/identity/conditionalAccess/namedLocations --query "value[].[id,displayName]" -o tsv
   az rest --url https://graph.microsoft.com/v1.0/policies/authenticationStrengthPolicies --query "value[?policyType=='custom'].[id,displayName]" -o tsv
   az ad group list --filter "startswith(displayName,'iac-legacy')" --query "[].[id,displayName]" -o tsv
   az ad app list --filter "displayName eq 'iac-legacy-zoom'" --query "[].[id,displayName]" -o tsv   # application object ID
   az ad sp list --filter "displayName eq 'iac-legacy-zoom'" --query "[].[id,displayName]" -o tsv
   ```
   Import ID formats (azuread 3.x): `/identity/conditionalAccess/policies/<id>`, `/identity/conditionalAccess/namedLocations/<id>`, `/policies/authenticationStrengthPolicies/<id>`, `/groups/<id>`, `/applications/<object id>`, `/servicePrincipals/<id>`. Bare IDs fail.
4. **Plan until clean, import only:**
   ```bash
   source ~/.okta-lab/entra-legacy-env.sh
   terraform -chdir=entra/legacy init
   terraform -chdir=entra/legacy plan -var-file=tenants/lab.tfvars -out=/tmp/legacy.tfplan
   ```
   If your objects differ from the checked-in code (different settings), fix the `.tf` files until the plan shows only `import` actions. Then apply the saved plan (`iac-reader` can write this state: it has Storage Blob Data Contributor on `tfstate-prod`; import changes only state, not Entra), and confirm:
   ```bash
   terraform -chdir=entra/legacy apply /tmp/legacy.tfplan
   terraform -chdir=entra/legacy plan -var-file=tenants/lab.tfvars -detailed-exitcode   # exit 0
   ```
   Every resource here has `prevent_destroy`, and a Conftest rule blocks any destroy in this root.

---

## 10. Pipeline identities

| Identity | Federated credential suffix | Graph application permissions | Storage role |
|---|---|---|---|
| `iac-planner` | `pull_request` | `Directory.Read.All`, `Policy.Read.All` | Storage Blob Data **Reader** on `tfstate-prod`, `tfstate-nonprod` |
| `iac-applier` | `environment:nonprod`, `environment:prod` | `Application.ReadWrite.All`, `Group.ReadWrite.All`, `Policy.ReadWrite.ConditionalAccess`, `Policy.Read.All`, `Policy.ReadWrite.ApplicationConfiguration`, `AppRoleAssignment.ReadWrite.All`, `Directory.Read.All` | Storage Blob Data **Contributor** on `tfstate-prod`, `tfstate-nonprod` |
| `iac-reader` | (part 6) | (part 9) | (part 6) |

```bash
PLANNER=$(az ad app create --display-name iac-planner --query appId -o tsv); az ad sp create --id $PLANNER
APPLIER=$(az ad app create --display-name iac-applier --query appId -o tsv); az ad sp create --id $APPLIER
fic $PLANNER github-pull-request pull_request
fic $APPLIER github-env-nonprod environment:nonprod
fic $APPLIER github-env-prod environment:prod
grant $PLANNER Directory.Read.All Policy.Read.All
grant $APPLIER Application.ReadWrite.All Group.ReadWrite.All Policy.ReadWrite.ConditionalAccess Policy.Read.All \
  Policy.ReadWrite.ApplicationConfiguration AppRoleAssignment.ReadWrite.All Directory.Read.All
az login --tenant <tenant-id>      # as bg-admin-01 for consent
az ad app permission admin-consent --id $PLANNER
az ad app permission admin-consent --id $APPLIER
az login --tenant <tenant-id>      # back to your own account
sp() { az ad sp show --id $1 --query id -o tsv; }
for c in tfstate-prod tfstate-nonprod; do
  az role assignment create --assignee-object-id $(sp $PLANNER) --assignee-principal-type ServicePrincipal --role "Storage Blob Data Reader" --scope "$(cscope $c)"
  az role assignment create --assignee-object-id $(sp $APPLIER) --assignee-principal-type ServicePrincipal --role "Storage Blob Data Contributor" --scope "$(cscope $c)"
done
```
(`fic`, `grant`, `cscope` are the helpers from parts 6 and 9; define them again in a new terminal.) Register every credential, permission and role.

**Create each state file once.** The read-only planner cannot create a state file (lab 1: `403 AuthorizationPermissionMismatch`, "failed to lock azure state"). With your own login:
```bash
for c in tfstate-prod tfstate-nonprod; do for r in entra/platform entra/waves/wave-00; do
  terraform -chdir=$r init -reconfigure -backend-config=container_name=$c
done; done
```

---

## 11. GitHub settings

```bash
gh variable set AZURE_TENANT_ID   --body <tenant-id>
gh variable set READER_CLIENT_ID  --body $READER
gh variable set PLANNER_CLIENT_ID --body $PLANNER
gh variable set APPLIER_CLIENT_ID --body $APPLIER

# Environments: nonprod open; prod needs a reviewer and runs from main only
gh api -X PUT repos/$O/$R/environments/nonprod
REVIEWER_ID=$(gh api users/<reviewer-login> --jq .id)
gh api -X PUT repos/$O/$R/environments/prod --input - <<EOF
{"reviewers":[{"type":"User","id":$REVIEWER_ID}],"prevent_self_review":false,
 "deployment_branch_policy":{"protected_branches":false,"custom_branch_policies":true}}
EOF
gh api -X POST repos/$O/$R/environments/prod/deployment-branch-policies -f name=main -f type=branch

# Labels for the change gate and drift
gh label create change --color 0E8A16
for s in draft assess scheduled implement closed cancelled; do gh label create "change:$s" --color C5DEF5; done
gh label create drift --color D93F0B
```

- **One person:** `prevent_self_review` must be `false`, or you cannot approve your own prod deployment. With a second real reviewer, set it to `true` and make them the reviewer. Do not create a second GitHub account for yourself; GitHub's terms allow one free personal account per person.
- **Branch protection on `main`:** run the `gh api -X PUT .../branches/main/protection` command in [git-check-plans-info.md](git-check-plans-info.md). It requires the four checks `policy-selftest`, `change-gate / check`, `plan (lab-np)`, `plan (lab)`, a PR, and **0 approvals** (you cannot approve your own PR). Do this after part 12's first PR has run once, so GitHub knows the check names.
- The snapshot never pushes to `main`; it writes counts to the unprotected branch `inventory-counts`. Do not protect that branch.

---

## 12. First PR: build platform and wave-00 through the pipeline

`entra/platform` creates the staff groups (`iac-it`, `iac-custserv`, `iac-finance`) and a named location. `entra/waves/wave-00` creates 4 SAML apps, 1 OIDC app, claims, group assignments and the report-only CA policy `LAB-CA10`. Each builds twice: `lab` (prod, names `iac-*`) and `lab-np` (nonprod copy in the same tenant, names `iac-np-*`).

1. **Change ticket.** Open an issue with labels `change` and `change:scheduled`, and a body containing (UTC (Coordinated Universal Time) times, a window that covers now and the merge):
   ```
   window_start: 2026-11-01T00:00:00Z
   window_end: 2026-11-03T00:00:00Z
   ```
2. **PR.** On a branch, make your porting changes (tfvars tenant IDs, IDs in `data.tf`), push, and open a PR to `main` from the template. Set its first line to `Change: github:<issue number>`.
3. **Checks.** Expect all four green. On the first PR, `lab` plans the platform and wave-00 creates, and wave-00 may show "skipped" while platform objects do not exist yet; that is by design.
4. **Merge,** then open the **apply** run (Actions → apply → newest run). `nonprod` applies on its own. For prod, click **View** in the yellow banner, tick **prod**, **Approve and deploy**.
5. **Clean after apply.** Each root re-plans after its apply and must show no changes; fresh SAML apps may need the one extra apply the script performs ("applied, clean after a 2nd apply").
6. **Check in the tenant:**
   ```bash
   az ad group list --filter "startswith(displayName,'iac-')" --query "[].displayName" -o tsv
   az ad app list --filter "startswith(displayName,'iac-')" --query "[].displayName" -o tsv
   ```
7. Close the issue: replace `change:scheduled` with `change:closed`.

From here, every change to `entra/` goes through a PR like this one.

---

## 13. Test users and sign-in tests

1. **Test users** (stand-ins for HR or SailPoint provisioning; lab only):
   ```bash
   P='<shared test password>'
   mk() { az ad user create --display-name "$1" --user-principal-name $2@$D --password "$P" --force-change-password-next-sign-in false >/dev/null
          az rest --method PATCH --url https://graph.microsoft.com/v1.0/users/$2@$D --body "{\"department\":\"$3\",\"jobTitle\":\"$4\",\"employeeId\":\"$5\"}"; }
   mk "Ada Reyes" ada.reyes IT "IT Manager" 1001
   mk "Cara Lind" cara.lind CustServ "Support Lead" 1002
   mk "Gus Tanaka" gus.tanaka Finance "Accountant" 1003
   add() { az ad group member add --group $1 --member-id $(az ad user show --id $2@$D --query id -o tsv); }
   add iac-it ada.reyes; add iac-it cara.lind; add iac-custserv cara.lind; add iac-finance gus.tanaka
   ```
   Store the password in the password manager.
2. **SAML:** private window → `https://myapps.microsoft.com/<tenant-domain>.onmicrosoft.com` → sign in as Ada → open each tile. The test site shows the claims (NameID, department, title, employeeNumber on hr-portal). Screenshot to `docs/evidence/`.
3. **OIDC:** private window → https://oidcdebugger.com:

   | Field | Value |
   |---|---|
   | Authorize URI | `https://login.microsoftonline.com/<tenant-id>/oauth2/v2.0/authorize` |
   | Client ID | `az ad app list --filter "displayName eq 'iac-oidc-portal'" --query "[0].appId" -o tsv` |
   | Scope | `openid profile email` |
   | Response type | `id_token` only |
   | Response mode | `form_post` |

   Sign in as Ada: **Success**, and the decoded token has `department: IT`. Then as Gus (not assigned): error **AADSTS50105**. Screenshot both. The implicit flow is a lab test path only; production apps use authorization code with PKCE (Proof Key for Code Exchange).
4. **Claims experiment (optional):** on the `iac-np-*` copies, edit claims in the portal (Enterprise apps → app → Single sign-on → Attributes & Claims) and run a local plan of nonprod wave-00 to see what each claims method detects. Lab 1 result: README step 2.6a.

---

## 14. Pipeline exit tests and drift

| Test | How | Pass |
|---|---|---|
| Rule-breaking PR | Valid change ticket; in `entra/waves/wave-00/ca-policies.tf` set `excluded_groups = []` | Both `plan` checks fail on "CA policy must exclude bg-ca-exclusion"; merge blocked. Close unmerged |
| PR without a change ticket | Comment-only change; no `Change:` line | `change-gate / check` fails; merge blocked. Close unmerged |
| Compliant PR | Part 12 | nonprod applies on merge; prod only after approval |
| Induced drift | After a clean nightly drift run (10:41 UTC), change one prod object in the portal (for example the description of group `iac-finance`), then `gh workflow run drift.yml` | Exactly one issue labeled `drift` opens. Undo the portal change; the next run comments or stays clean |

Drift is never fixed automatically. Either put the portal change back, or codify it in a PR.

---

## 15. Daily operation

| Routine | Where |
|---|---|
| Okta snapshot, 09:17 UTC nightly | Actions → snapshot. Red = Okta changed outside code |
| Entra drift check, 10:41 UTC nightly (prod) | Actions → drift; issues labeled `drift` |
| Any Entra change | Change issue → branch → PR with `Change: github:<n>` → green checks → merge → approve prod |
| Local plan of nonprod (read only) | `TF_DATA_DIR=~/.okta-lab/tfdata-<root>-np terraform -chdir=<root> init -reconfigure -lock=false -backend-config=container_name=tfstate-nonprod` then `plan -lock=false -var-file=tenants/lab-np.tfvars` |
| Before every commit | `terraform fmt -recursive && terraform validate` (in the root you changed) |
| Every grant | A row in `docs/permission-register.md` |

**End of run cleanup:** revoke the Okta seeding token; remove the `iac-reader` local certificate (`az ad app credential delete`); move test passwords into the password manager and delete the files in `~/.okta-lab/`.

---

## 16. Troubleshooting (lab 1 lessons)

| Symptom | Cause | Fix |
|---|---|---|
| `AADSTS700213` at `azure/login` | Federated subject uses names; repo sends the immutable ID format | Rebuild the subject from part 6 step 4 |
| `403 AuthorizationPermissionMismatch`, "failed to lock azure state" on a PR | State file does not exist; the planner cannot create it | Part 10, "Create each state file once" |
| Storage create: "SubscriptionNotFound" | `Microsoft.Storage` provider not registered | Part 6 step 2 |
| `az login` blocked (AADSTS530035) or device code refused | Security defaults | Browser sign-in in a private window |
| CLI gets 403 on authentication strengths | User token lacks `Policy.Read.All` | Plan `entra/legacy` as `iac-reader` (part 9) |
| Okta zones return 403 | Reader lacks `okta.networkZones.read` | Grant it (part 5) |
| `InvalidUniqueTenantIdentifierAsPerAppPolicy` / `HostNameNotOnVerifiedDomain` on a SAML identifier | Default app management policy | Set the service principal to SAML first, then add the identifier (the code does this) |
| "Permission being assigned was not found" | Template roles deleted by `azuread_application` | Declare the `User` role (the code does this) |
| "Provider produced inconsistent result" or 404 right after create | Entra replication delay | Re-run; the pipeline retries once |
| Plan not clean right after a fresh SAML app | Template adds a `user_impersonation` scope | The pipeline's post-apply apply removes it |
| PR "BLOCKED" with all checks green | Branch protection requires an approval | Set approvals to 0 (part 11) |
| Prod approval window has no tick box | `prevent_self_review` is on and you triggered the run | Turn it off (one-person lab) |
| SAML portal claims page shows the wrong claims | A claims mapping policy is assigned; the portal shows defaults | Read claims from Graph or the code, not that page |
| New Okta users cannot sign in ("Unable to sign in", ENROLL in the system log) | Built-in Okta Dashboard policy requires 2FA | Seed script sets its catch-all to password only |
| Microsoft 365 trial checkout asks for a billing profile, then fails | Commerce flow from the wrong account | Start the trial from Entra admin center → Licenses → Try/Buy as a work account in the tenant |
