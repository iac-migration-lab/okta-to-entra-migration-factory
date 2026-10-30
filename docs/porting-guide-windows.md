# Porting Guide for Windows: a Clean Repo with PowerShell Only

How to turn this repo into a clean starting repo on a Windows 10 or 11 PC, using PowerShell 7 and Windows tools only (no WSL (Windows Subsystem for Linux), no Git Bash): copy it, strip every piece of lab material, fill in your own values, check it, and rebuild.

Read with:
- [porting-guide.md](porting-guide.md): the same port through WSL2, keeping the lab's code and docs.
- [build-by-hand.md](build-by-hand.md): portal clicks and the reason for each step. This guide gives the PowerShell for the command steps and points there for the clicks.

**Conventions**
- Run every block in **PowerShell 7** (`pwsh`, Windows Terminal → PowerShell), not Windows PowerShell 5.1 and not Command Prompt. Run as your normal user unless a step says Administrator.
- Quote any argument that has `=` and a dot or a variable: `"-var-file=tenants/lab.tfvars"`, `"-chdir=$r"`. Unquoted, PowerShell splits `-var-file=tenants/lab.tfvars` at the dot and passes `-chdir=$r` without expanding `$r` (both seen in testing).
- In `az --query`, avoid `|` (the Azure CLI runs through a `.cmd` file, where `|` breaks the command); the blocks here already do.
- Paste one block at a time. Blocks set `$ErrorActionPreference = 'Stop'` so a failure stops instead of carrying on.
- Values in `<angle brackets>` are yours to fill in. In the stripped repo, values still to fill look like `__TENANT_ID__` (section 5).
- Secrets live in `$HOME\.iac-secrets` (only your account can read it, section 2) and a password manager. Never in the repo.
- Tested 2026-10-30 with PowerShell 7.6.6 on macOS against a copy of this repo and the lab Okta org: strip, strip check, fill, token check, `terraform validate` of every kept root, the policy self-test, the Okta token and refused write (HTTP 403), import generation (26 blocks, then `plan -generate-config-out`: 26 to import), and the certificate and env file. Not run yet on a real Windows PC, and not tested: winget, the tool download block, `icacls`, `Get-Clipboard`, and every `az`/`gh` call. Log what differs.

**What "lab material" means here:** the lab's records (findings log, permission register, evidence, counts), its run notes and prompts, the Okta seed that builds dummy data, the Terraform files that describe the lab's own Okta and Entra objects, and every lab identifier (org, tenant, subscription, storage account, GitHub org, object IDs, mailbox, admin names). What stays is the method: folder layout, providers and backends, pipelines, policy rules, and the method docs. The original lab repo stays public as the worked example to copy patterns from.

**What still runs as bash:** `.github/scripts/*.sh`, `okta-inventory/snapshot-export.sh` and `policy/test.sh` run inside GitHub Actions on GitHub's Ubuntu runners, never on your PC. Locally, this guide replaces each bash script you would run with PowerShell: the policy self-test (section 6), the Okta reader check (section 7.2), and the Okta ID listing (section 7.3).

---

## 1. Tools

1. **PowerShell 7, Git, Azure CLI (command-line interface), GitHub CLI** with winget. In any terminal:
   ```powershell
   winget install --id Microsoft.PowerShell --version 7.6.6 --exact
   winget install --id Git.Git --exact
   winget install --id Microsoft.AzureCLI --version 2.90.0 --exact
   winget install --id GitHub.cli --version 2.103.0 --exact
   ```
   Close and reopen Windows Terminal, then use the PowerShell 7 profile. UNVERIFIED: that winget offers these exact versions; if one is missing, `winget show --id <id> --versions` lists what it has, and record the version you used in the findings log.
2. **Terraform 1.16.4 and Conftest 0.71.0,** checksum-verified, into `$HOME\iac-tools\bin` (outside the repo):
   ```powershell
   $ErrorActionPreference = 'Stop'
   $TF = '1.16.4'; $CONFTEST = '0.71.0'
   $A = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { @{ tf = 'arm64'; cf = 'arm64' } } else { @{ tf = 'amd64'; cf = 'x86_64' } }
   $Bin = "$HOME\iac-tools\bin"; $Dl = "$HOME\iac-tools\dl"
   New-Item -ItemType Directory -Force $Bin, $Dl | Out-Null
   function Get-Verified($Url, $SumsUrl, $Name) {
     $file = Join-Path $Dl $Name
     Invoke-WebRequest $Url -OutFile $file
     $line = ((Invoke-WebRequest $SumsUrl).Content -split "`n") | Where-Object { $_ -match " $([regex]::Escape($Name))$" }
     if (-not $line) { throw "No checksum line for $Name" }
     if ((Get-FileHash $file -Algorithm SHA256).Hash -ne $line.Split(' ')[0].ToUpper()) { throw "Checksum mismatch: $Name" }
     "$Name checksum OK"; $file
   }
   $z = Get-Verified "https://releases.hashicorp.com/terraform/$TF/terraform_${TF}_windows_$($A.tf).zip" `
     "https://releases.hashicorp.com/terraform/$TF/terraform_${TF}_SHA256SUMS" "terraform_${TF}_windows_$($A.tf).zip"
   Expand-Archive $z[-1] -DestinationPath $Bin -Force
   $z = Get-Verified "https://github.com/open-policy-agent/conftest/releases/download/v$CONFTEST/conftest_${CONFTEST}_Windows_$($A.cf).zip" `
     "https://github.com/open-policy-agent/conftest/releases/download/v$CONFTEST/checksums.txt" "conftest_${CONFTEST}_Windows_$($A.cf).zip"
   Expand-Archive $z[-1] -DestinationPath $Bin -Force
   ```
3. **Put the tools on the path** at the start of every PowerShell session, then check:
   ```powershell
   $env:Path = "$HOME\iac-tools\bin;$env:Path"
   terraform -version     # 1.16.4
   conftest --version     # 0.71.0
   (az version | ConvertFrom-Json).'azure-cli'      # 2.90.0
   gh --version; git --version
   gh auth login          # GitHub.com, HTTPS, log in with a web browser
   ```
4. **Git line endings.** The repo's `.gitattributes` keeps Linux line endings (LF) on checkout; the pipeline's bash scripts break with Windows ones. Also set:
   ```powershell
   git config --global core.autocrlf false
   ```
   Edit files in VS Code (Visual Studio Code), not Notepad.

## 2. Secrets folder

```powershell
$S = "$HOME\.iac-secrets"
New-Item -ItemType Directory -Force $S | Out-Null
icacls $S /inheritance:r /grant:r "${env:USERNAME}:(OI)(CI)F"
icacls $S        # expect only your account, with (OI)(CI)(F)
```
Files you create inside inherit that access. This replaces `chmod 700`/`chmod 600`.

## 3. Copy the repo with a fresh history

```powershell
$ErrorActionPreference = 'Stop'
$Repo = "$HOME\Projects\<new-repo>"
git clone https://github.com/iac-migration-lab/okta-to-entra-migration-factory.git $Repo
Set-Location $Repo
Remove-Item .git -Recurse -Force
git init -b main
```

## 4. Strip the lab material

| Removed | Why |
|---|---|
| `CLAUDE.md`, `scripts/`, `docs/evidence/`, `docs/inventory-counts.md`, `docs/run-1-scope.md`, `docs/start-phase-1.md`, `docs/wave-01-plan.md`, `docs/claude-code-prompts.md`, `docs/workstation-vm.md`, `docs/lab-naming.md`, `docs/build-phases.md` | Lab records, run notes, prompts and personal setup |
| `okta-inventory/seed/`, `docs/okta-seed-spec.md` | Builds the lab's dummy Okta data; a real source org already exists |
| Every `okta-inventory/*.tf` except `backend.tf`, `providers.tf`, `versions.tf` | They describe the lab's Okta objects; you regenerate them from your org (section 7.3) |
| Every `entra/legacy/*.tf`, `entra/platform/*.tf` and `azure/bootstrap/*.tf` except `backend.tf`, `providers.tf`, `versions.tf`, `variables.tf`, `locals.tf` | The lab's brownfield objects, staff groups, named location and budget |
| `docs/porting-guide.md` and this guide | They hold the lab's values (this guide's strip list). Keep following this guide from the source repo |
| `entra/waves/wave-00/`, `entra/waves/wave-01/` | The lab's test apps. Copy patterns from the lab repo when you write your first wave |
| Contents of `docs/findings-log.md`, `docs/permission-register.md`, `.github/okta-cutover-apps.json`, `README.md` | Reset to empty starting versions |
| Every lab identifier in the remaining files | Replaced with a `__TOKEN__` you fill in section 5 |

```powershell
$ErrorActionPreference = 'Stop'
Set-Location $Repo

# 1. Lab-only files and folders
$remove = 'CLAUDE.md', 'scripts', 'okta-inventory/seed', 'entra/waves/wave-00', 'entra/waves/wave-01',
  'docs/evidence', 'docs/archive', 'docs/inventory-counts.md', 'docs/run-1-scope.md', 'docs/start-phase-1.md',
  'docs/wave-01-plan.md', 'docs/claude-code-prompts.md', 'docs/workstation-vm.md', 'docs/okta-seed-spec.md',
  'docs/lab-naming.md', 'docs/build-phases.md', 'docs/porting-guide.md', 'docs/porting-guide-windows.md'
$remove | Where-Object { Test-Path $_ } | ForEach-Object { Remove-Item $_ -Recurse -Force }

# 2. Terraform files that describe lab objects (keep each root's plumbing)
$keep = 'backend.tf', 'providers.tf', 'versions.tf', 'variables.tf', 'locals.tf'
foreach ($root in 'okta-inventory', 'entra/legacy', 'entra/platform', 'azure/bootstrap') {
  Get-ChildItem $root -Filter *.tf | Where-Object Name -notin $keep | Remove-Item
}

# 3. Records and lab-specific files, reset (LF line endings, UTF-8 without BOM)
function Write-Lf($Path, [string[]]$Lines) { [IO.File]::WriteAllText((Join-Path $Repo $Path), ($Lines -join "`n") + "`n") }
Write-Lf 'docs/findings-log.md' @(
  'Current run: 1', 'Current phase: 0', '', '# Findings Log', '',
  'Append only. Newest entry at the bottom. Never rewrite an earlier entry; correct it with a new one.', '',
  '## Entry template', '', '```', '## YYYY-MM-DD, Run N, Phase N, short title', '- What the docs said:',
  '- What actually happened:', '- Time taken:', '- Evidence:', '- Change to the client plan, if any:',
  '- Accepted risks added, if any:', '```', '', '---')
Write-Lf 'docs/permission-register.md' @(
  '# Permission Register', '', 'Every grant (scope, admin role, Graph permission, RBAC role, token, secret, consent), written at the time of the grant.', '',
  'Verdicts: **OK** (use as is in production), **Changes** (OK with the change noted), **Not OK** (do not use in production).', '',
  '| # | Date | Run | Identity | Granted | Why | Verdict | Production should use |', '|---|---|---|---|---|---|---|---|')
Write-Lf '.github/okta-cutover-apps.json' @(
  '{', '  "_comment": "Okta app and group IDs for okta-cutover.yml, per wave (from okta-inventory/imports.tf). Groups in assignment priority order."', '}')
Write-Lf 'README.md' @(
  '# Okta to Entra ID Migration as Code', '',
  'Okta read as code, Entra ID written as code, and a GitHub pipeline between them.', '',
  '- Build: [docs/build-by-hand.md](docs/build-by-hand.md); on Windows, the source repo''s docs/porting-guide-windows.md.',
  '- Records: [docs/findings-log.md](docs/findings-log.md), [docs/permission-register.md](docs/permission-register.md).')
New-Item -ItemType Directory -Force docs/evidence | Out-Null
Write-Lf 'docs/evidence/.gitkeep' @()

# 4. Lab identifiers -> tokens (longest first; literal, case-sensitive)
$tokens = [ordered]@{
  'iac-migration-lab/okta-to-entra-migration-factory' = '__GITHUB_ORG__/__GITHUB_REPO__'
  'lamigrationlaboutlook.onmicrosoft.com'             = '__TENANT_DOMAIN__'
  'la-migration-lab@outlook.com'                      = '__ADMIN_EMAIL__'
  'mark@lencioni.io'                                  = '__OKTA_ADMIN_EMAIL__'
  'okta-to-entra-migration-factory'                   = '__GITHUB_REPO__'
  'iac-migration-lab'                                 = '__GITHUB_ORG__'
  'integrator-2631921'                                = '__OKTA_ORG__'
  'bed5d4c3-98f0-4c73-9e4c-0b6cd3b9a0a4'              = '__TENANT_ID__'
  '6ea51c80-90de-4914-bbc6-2af9b54bba9f'              = '__SUBSCRIPTION_ID__'
  'stiaclabtfstate02'                                 = '__STORAGE_ACCOUNT__'
  '21008cb0-56d6-4fc4-9f1c-9e20dc1d5620'              = '__BG_CA_EXCLUSION_GROUP_ID__'
  'b4a88d50-ea8b-48e2-8853-7e4bd1c1c841'              = '__OWNER_USER_ID__'
  '1028c48b-19bd-4852-85a4-2cd92e274b06'              = '__ADMIN_USER_ID__'
  '0oa18siafpuScaofm698'                              = '__OKTA_READER_CLIENT_ID__'
  'iac-okta-reader-2026-10-16'                        = '__OKTA_READER_KEY_ID__'
  '0oa1965gqj5LStpWJ698'                              = '__OKTA_CUTOVER_CLIENT_ID__'
  'iac-okta-cutover-2026-10-26'                       = '__OKTA_CUTOVER_KEY_ID__'
  'rst188pzg3iEP5uGh698'                              = '__OKTA_DEFAULT_AUTH_POLICY_ID__'
  'iaclab.example'                                    = '__LOGIN_DOMAIN__'
  '336396784'                                         = '__GITHUB_ORG_ID__'
  '1399352055'                                        = '__GITHUB_REPO_ID__'
}
$files = Get-ChildItem -Recurse -File | Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' -and $_.Extension -notin '.png', '.jpg', '.docx', '.pdf' }
foreach ($f in $files) {
  $t = [IO.File]::ReadAllText($f.FullName); $n = $t
  foreach ($k in $tokens.Keys) { $n = $n.Replace($k, $tokens[$k]) }
  if ($n -ne $t) { [IO.File]::WriteAllText($f.FullName, $n); "tokenized $($f.FullName.Substring($Repo.Length + 1))" }
}
```

Keep `$tokens` for the next check, or paste the block's `$tokens` part again in a new session.

**Check the strip** (must print nothing):
```powershell
$files = Get-ChildItem $Repo -Recurse -File | Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' }
$files | Select-String -SimpleMatch -Pattern ([string[]]$tokens.Keys)
```

Then list any GUID (globally unique identifier) left, and check each is a Microsoft-wide constant (Microsoft Graph `00000003-0000-0000-c000-000000000000`, the non-gallery template `8adf8e6e-…`, the SAML `User` role `18d14569-…`, all zeros), not a lab object:
```powershell
$files | Select-String -Pattern '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' -AllMatches |
  ForEach-Object { $_.Matches.Value } | Sort-Object -Unique
```

Prose that still says "lab 1" or "run 1" is method history, not an identifier. Review the list and reword what you want gone:
```powershell
$files | Select-String -Pattern '\b[Ll]ab 1\b|\b[Rr]un 1\b' | Group-Object Path | Select-Object Count, Name
```

## 5. Fill in your values

Collect your values first (build-by-hand part 1 for the accounts; IDs you only get later can stay as tokens until then):

| Token | Your value | Where it comes from |
|---|---|---|
| `__OKTA_ORG__` | | Okta org name (the part before `.okta.com`) |
| `__OKTA_READER_CLIENT_ID__`, `__OKTA_READER_KEY_ID__` | | Section 7.2 |
| `__OKTA_CUTOVER_CLIENT_ID__`, `__OKTA_CUTOVER_KEY_ID__` | | The cutover identity (build-by-hand, Lab Phase 4 note) |
| `__OKTA_DEFAULT_AUTH_POLICY_ID__` | | Section 7.3 (`ACCESS_POLICY` named "Default Policy") |
| `__LOGIN_DOMAIN__`, `__OKTA_ADMIN_EMAIL__`, `__ADMIN_EMAIL__` | | Your accounts |
| `__TENANT_ID__`, `__TENANT_DOMAIN__`, `__SUBSCRIPTION_ID__` | | `az account show --query '{tenant:tenantId, sub:id}'` |
| `__STORAGE_ACCOUNT__` | | Section 7.4 (globally unique, lower case, 3 to 24 letters and digits) |
| `__GITHUB_ORG__`, `__GITHUB_REPO__`, `__GITHUB_ORG_ID__`, `__GITHUB_REPO_ID__` | | Section 7.1 |
| `__BG_CA_EXCLUSION_GROUP_ID__`, `__OWNER_USER_ID__`, `__ADMIN_USER_ID__` | | Section 7.5 |

```powershell
$ErrorActionPreference = 'Stop'
Set-Location $Repo
$values = [ordered]@{
  '__OKTA_ORG__'    = '<okta-org>'
  '__TENANT_ID__'   = '<tenant-id>'
  # one line per token you have a value for
}
Get-ChildItem -Recurse -File | Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' } | ForEach-Object {
  $t = [IO.File]::ReadAllText($_.FullName); $n = $t
  foreach ($k in $values.Keys) { $n = $n.Replace($k, $values[$k]) }
  if ($n -ne $t) { [IO.File]::WriteAllText($_.FullName, $n); "filled $($_.Name)" }
}
```
Run it again whenever you learn more values. Tokens still to fill:
```powershell
Get-ChildItem -Recurse -File | Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' } |
  Select-String -Pattern '__[A-Z0-9_]+__' -AllMatches | ForEach-Object { $_.Matches.Value } | Group-Object | Select-Object Count, Name
```
Before the first PR (section 7.8) this must print nothing.

## 6. Checks before every commit

```powershell
$ErrorActionPreference = 'Stop'
Set-Location $Repo
terraform fmt -recursive -check; if ($LASTEXITCODE) { throw 'run terraform fmt -recursive' }

# Policy self-test (PowerShell version of policy/test.sh)
Push-Location policy
try {
  conftest test --policy . --data fixtures/legacy-context.json fixtures/pass-plan.json
  if ($LASTEXITCODE) { throw 'FAIL: pass fixture denied' }
  $out = conftest test --no-color --policy . --data fixtures/legacy-context.json fixtures/fail-plan.json | Out-String
  if (-not $LASTEXITCODE) { throw 'FAIL: fail fixture passed' }
  foreach ($w in 'exclude bg-ca-exclusion', 'start report-only', 'must not be destroyed') {
    if (-not $out.Contains($w)) { throw "FAIL: missing denial: $w" }
  }
  'policy self-test OK'
} finally { Pop-Location }

# Line endings: must print nothing (no Windows line endings in tracked files)
git add -A; git ls-files --eol | Select-String 'i/crlf'

# Links in docs that point at removed files
Get-ChildItem -Recurse -Filter *.md | ForEach-Object {
  $dir = $_.DirectoryName
  Select-String -Path $_.FullName -Pattern '\]\(([^)#:]+\.md)' -AllMatches | ForEach-Object {
    foreach ($m in $_.Matches) { if (-not (Test-Path (Join-Path $dir $m.Groups[1].Value))) { "$($_.Path):$($_.LineNumber) -> $($m.Groups[1].Value)" } }
  }
}
```
The last check lists dead links (for example `docs/README.md` rows for removed docs). Delete those rows.

## 7. Rebuild in PowerShell

Follow [build-by-hand.md](build-by-hand.md) parts 1 to 14 for the order, the portal clicks and the reasons. The command steps in PowerShell:

### 7.1 Accounts, Okta engine, GitHub repo (build-by-hand parts 1 and 3)
```powershell
(Invoke-RestMethod https://<okta-org>.okta.com/.well-known/okta-organization).pipeline   # must be idx (Identity Engine)
Set-Location $Repo
git add -A; git commit -m "Clean start from the identity-as-code method"
gh repo create <github-org>/<repo> --public --source . --push
$O = '<github-org>'; $R = '<repo>'
gh api repos/$O/$R/actions/oidc/customization/sub        # expect use_immutable_subject: true
$Prefix = "repo:$O@$(gh api orgs/$O --jq .id)/$R@$(gh api repos/$O/$R --jq .id)"
$Prefix
```
The repo must be **public, in a GitHub organization** (free private repos have no environment reviewers or secrets). If `use_immutable_subject` is false, `$Prefix = "repo:$O/$R"`.

### 7.2 Okta read-only identity (build-by-hand part 5)
Create `iac-okta-reader` in the Admin Console as in build-by-hand part 5 steps 1 to 5. Copy the private key (PEM), then save it from the clipboard:
```powershell
((Get-Clipboard -Raw) -replace "`r", '') | Set-Content -NoNewline "$S\iac-okta-reader.pem"
Get-Content "$S\iac-okta-reader.pem" -TotalCount 1      # a -----BEGIN ... PRIVATE KEY----- line
```

Token function (private key JWT (JSON Web Token), no API token; replaces `verify-reader.sh`):
```powershell
function Get-OktaToken([string]$OrgUrl, [string]$ClientId, [string]$KeyId, [string]$KeyFile, [string[]]$Scopes) {
  $b64 = { param([byte[]]$b) [Convert]::ToBase64String($b).TrimEnd('=').Replace('+', '-').Replace('/', '_') }
  $aud = "$OrgUrl/oauth2/v1/token"; $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  $h = @{ alg = 'RS256'; typ = 'JWT'; kid = $KeyId } | ConvertTo-Json -Compress
  $p = @{ iss = $ClientId; sub = $ClientId; aud = $aud; iat = $now; exp = $now + 300; jti = [guid]::NewGuid().ToString('N') } | ConvertTo-Json -Compress
  $unsigned = (& $b64 ([Text.Encoding]::UTF8.GetBytes($h))) + '.' + (& $b64 ([Text.Encoding]::UTF8.GetBytes($p)))
  $rsa = [Security.Cryptography.RSA]::Create(); $rsa.ImportFromPem((Get-Content $KeyFile -Raw))
  $sig = $rsa.SignData([Text.Encoding]::ASCII.GetBytes($unsigned), [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1)
  $body = @{ grant_type = 'client_credentials'; scope = $Scopes -join ' '
    client_assertion_type = 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer'; client_assertion = "$unsigned.$(& $b64 $sig)" }
  (Invoke-RestMethod -Method Post -Uri $aud -Body $body -ContentType 'application/x-www-form-urlencoded').access_token
}
$OktaUrl = 'https://<okta-org>.okta.com'
$Tok = Get-OktaToken $OktaUrl '<reader client id>' '<kid>' "$S\iac-okta-reader.pem" `
  okta.apps.read, okta.users.read, okta.groups.read, okta.policies.read, okta.authorizationServers.read, okta.idps.read, okta.schemas.read, okta.networkZones.read
function Okta($Path) {   # one object per item (Invoke-RestMethod alone returns a list as one object)
  $r = Invoke-RestMethod "$OktaUrl/api/v1/$Path" -Headers @{ Authorization = "Bearer $Tok"; Accept = 'application/json' }; $r
}
"groups: $((Okta 'groups?limit=200').Count)  apps: $((Okta 'apps?limit=200').Count)  zones: $((Okta 'zones').Count)"
try { Invoke-RestMethod -Method Post "$OktaUrl/api/v1/groups" -Headers @{ Authorization = "Bearer $Tok" } -ContentType 'application/json' -Body '{"profile":{"name":"should-fail"}}'; 'WRITE ALLOWED: stop and fix the scopes' }
catch { "Write refused: HTTP $($_.Exception.Response.StatusCode.value__)" }   # expect 403
```
The token lasts one hour; run the `$Tok =` line again after that.

### 7.3 Okta inventory as code (build-by-hand part 7)
Write the import blocks from your org, then let Terraform generate the code:
```powershell
$ErrorActionPreference = 'Stop'
Set-Location $Repo
$imp = [Collections.Generic.List[string]]::new(); $used = @{}
function Add-Import($Type, $Label, $Id) {
  $n = ($Label.ToLower() -replace '[^a-z0-9]+', '_').Trim('_'); if ($n -match '^\d') { $n = "x_$n" }
  $k = "$Type.$n"; if ($used[$k]) { $n = "${n}_$Id"; $k = "$Type.$n" }; $used[$k] = 1
  $imp.Add("import {`n  to = $k`n  id = `"$Id`"`n}`n")
}
Okta 'groups?limit=200' | Where-Object type -eq 'OKTA_GROUP' | ForEach-Object { Add-Import okta_group $_.profile.name $_.id }
foreach ($a in Okta 'apps?limit=200') {
  $t = @{ SAML_2_0 = 'okta_app_saml'; OPENID_CONNECT = 'okta_app_oauth' }[$a.signOnMode]
  if ($a.settings.oauthClient.application_type -eq 'service') { "skipped service app $($a.label) (automation identity)" }
  elseif ($t) { Add-Import $t $a.label $a.id; Add-Import okta_app_group_assignments $a.label $a.id }
  else { "skipped app $($a.label) ($($a.signOnMode))" }
}
Okta 'zones' | ForEach-Object { if ($_.system) { "skipped system zone $($_.name)" } else { Add-Import okta_network_zone $_.name $_.id } }
@{ PASSWORD = 'okta_policy_password'; OKTA_SIGN_ON = 'okta_policy_signon'; ACCESS_POLICY = 'okta_app_signon_policy' }.GetEnumerator() |
  ForEach-Object { $t = $_.Value; Okta "policies?type=$($_.Key)" | ForEach-Object {
    if ($_.system) { "skipped system policy $t $($_.id) $($_.name)" } else { Add-Import $t $_.name $_.id } } }
Okta 'authorizationServers' | ForEach-Object { Add-Import okta_auth_server $_.name $_.id }
[IO.File]::WriteAllText("$Repo\okta-inventory\imports.tf", ($imp -join "`n"))
"$($imp.Count) import blocks written"
```
Read `imports.tf` and delete any block you will not manage as code (for example a built-in app's authentication policy that is not marked system). Skipped system objects are listed, not imported. The system `okta_app_signon_policy` in the skipped list is the org's default authentication policy; put its ID in `__OKTA_DEFAULT_AUTH_POLICY_ID__` if your code references it. Policy rules and authorization server scopes, claims and policies use `<parent id>/<child id>` IDs; add them the same way when you need them (build-by-hand part 7.1 table).

Plan with local state first, then move it to Azure (section 7.4 must be done before the move):
```powershell
$env:OKTA_API_PRIVATE_KEY = "$S\iac-okta-reader.pem"; $env:OKTA_API_PRIVATE_KEY_ID = '<kid>'
Move-Item okta-inventory\backend.tf "$env:TEMP\okta-backend.tf.hold"
terraform -chdir=okta-inventory init
terraform -chdir=okta-inventory plan "-generate-config-out=generated.tf"
```
Tidy `generated.tf` into per-type files (build-by-hand part 7.2), then plan until only imports show, apply (import only), and confirm `terraform -chdir=okta-inventory plan -detailed-exitcode` exits 0 (`$LASTEXITCODE`). Then:
```powershell
Move-Item "$env:TEMP\okta-backend.tf.hold" okta-inventory\backend.tf
terraform -chdir=okta-inventory init -migrate-state
terraform -chdir=okta-inventory plan -detailed-exitcode; $LASTEXITCODE     # 0
Remove-Item okta-inventory\terraform.tfstate*, okta-inventory\generated.tf -ErrorAction SilentlyContinue
```

### 7.4 Azure state storage and `iac-reader` (build-by-hand part 6)
```powershell
$ErrorActionPreference = 'Stop'
az login --tenant <tenant-id>; az account set --subscription <subscription-id>
az provider register --namespace Microsoft.Storage --wait
$RG = 'rg-iac'; $SA = '<storage-account>'; $LOC = 'westus3'
az storage account check-name --name $SA
az group create -n $RG -l $LOC
az storage account create -n $SA -g $RG -l $LOC --sku Standard_LRS `
  --allow-shared-key-access false --allow-blob-public-access false --min-tls-version TLS1_2
az storage account blob-service-properties update -n $SA -g $RG --enable-versioning true `
  --enable-delete-retention true --delete-retention-days 7 --enable-container-delete-retention true --container-delete-retention-days 7
$Me = az ad signed-in-user show --query id -o tsv
$ScopeSa = az storage account show -n $SA -g $RG --query id -o tsv
az role assignment create --assignee-object-id $Me --assignee-principal-type User --role 'Storage Blob Data Contributor' --scope $ScopeSa
foreach ($c in 'tfstate-prod', 'tfstate-nonprod', 'okta-exports') { az storage container create -n $c --account-name $SA --auth-mode login }
```
If the container step says "not authorized", wait a few minutes for the role and run the `foreach` line again.

Helpers (define again in every new session; they need `$Prefix` from 7.1 and `$ScopeSa`):
```powershell
function New-Fic($AppId, $Name, $Suffix) {   # federated credential, JSON through a file to avoid quoting problems
  $f = New-TemporaryFile
  @{ name = $Name; issuer = 'https://token.actions.githubusercontent.com'; subject = "${Prefix}:$Suffix"; audiences = @('api://AzureADTokenExchange') } |
    ConvertTo-Json | Set-Content $f
  az ad app federated-credential create --id $AppId --parameters "@$f"; Remove-Item $f
}
function Get-ContainerScope($c) { "$ScopeSa/blobServices/default/containers/$c" }
function Get-SpId($AppId) { az ad sp show --id $AppId --query id -o tsv }
$Graph = '00000003-0000-0000-c000-000000000000'
function Grant-Graph($AppId, [string[]]$Perms) {
  foreach ($p in $Perms) {
    $roleId = az ad sp show --id $Graph --query "appRoles[?value=='$p'].id" -o tsv
    az ad app permission add --id $AppId --api $Graph --api-permissions "$roleId=Role"
  }
}
```
```powershell
$Reader = az ad app create --display-name iac-reader --query appId -o tsv
az ad sp create --id $Reader
New-Fic $Reader github-okta-read environment:okta-read
New-Fic $Reader github-main ref:refs/heads/main
foreach ($c in 'tfstate-prod', 'okta-exports') {
  az role assignment create --assignee-object-id (Get-SpId $Reader) --assignee-principal-type ServicePrincipal `
    --role 'Storage Blob Data Contributor' --scope (Get-ContainerScope $c)
}
```
Register every credential and role. Then the GitHub environment `okta-read` and the first snapshot:
```powershell
gh api -X PUT repos/$O/$R/environments/okta-read
gh variable set AZURE_CLIENT_ID --env okta-read --body $Reader
gh variable set AZURE_TENANT_ID --env okta-read --body <tenant-id>
gh variable set OKTA_CLIENT_ID  --env okta-read --body <reader client id>
gh variable set OKTA_KEY_ID     --env okta-read --body <kid>
Get-Content "$S\iac-okta-reader.pem" -Raw | gh secret set OKTA_PRIVATE_KEY --env okta-read
gh workflow run snapshot.yml; Start-Sleep 10
gh run watch (gh run list --workflow snapshot.yml -L 1 --json databaseId --jq '.[0].databaseId')
```

### 7.5 Entra break-glass and brownfield (build-by-hand part 8)
```powershell
$D = '<tenant-domain>.onmicrosoft.com'
az ad user create --display-name 'Break Glass 01' --user-principal-name "bg-admin-01@$D" --password '<long passphrase>'
$Bg = az ad group create --display-name bg-ca-exclusion --mail-nickname bg-ca-exclusion --query id -o tsv
az ad group member add --group $Bg --member-id (az ad user show --id "bg-admin-01@$D" --query id -o tsv)
az ad group member add --group $Bg --member-id (az ad signed-in-user show --query id -o tsv)
"__BG_CA_EXCLUSION_GROUP_ID__ = $Bg"; "__OWNER_USER_ID__ = $(az ad signed-in-user show --query id -o tsv)"
```
Fill those tokens (section 5) and run the policy self-test (section 6). Global Administrator assignments, MFA, the P2 trial and security defaults are portal steps (build-by-hand part 8 steps 1 to 4). Every CA (Conditional Access) policy excludes `bg-ca-exclusion`; read them back:
```powershell
az rest --url 'https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies' `
  --query 'value[].{name:displayName, state:state, excludedGroups:conditions.users.excludeGroups}' -o json
```

### 7.6 Import the brownfield (`entra/legacy`, build-by-hand part 9)
Graph read permissions for `iac-reader`, consented from break-glass:
```powershell
Grant-Graph $Reader Directory.Read.All, Policy.Read.All
az login --tenant <tenant-id>      # as bg-admin-01
az ad app permission admin-consent --id $Reader
az login --tenant <tenant-id>      # back to your own account
```
Local certificate for `iac-reader` (60 days; register it), made with .NET instead of `openssl`:
```powershell
$rsa = [Security.Cryptography.RSA]::Create(2048)
$req = [Security.Cryptography.X509Certificates.CertificateRequest]::new('CN=iac-reader-local', $rsa,
  [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1)
$cert = $req.CreateSelfSigned([DateTimeOffset]::UtcNow.AddMinutes(-5), [DateTimeOffset]::UtcNow.AddDays(60))
$pfxPass = [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(24))
[IO.File]::WriteAllBytes("$S\iac-reader-local.pfx", $cert.Export('Pfx', $pfxPass))
Set-Content "$S\iac-reader-local.cert.pem" $cert.ExportCertificatePem()
az ad app credential reset --id $Reader --cert "@$S\iac-reader-local.cert.pem" --append
@{ ARM_TENANT_ID = '<tenant-id>'; ARM_CLIENT_ID = $Reader; ARM_CLIENT_CERTIFICATE_PATH = "$S\iac-reader-local.pfx"
   ARM_CLIENT_CERTIFICATE_PASSWORD = $pfxPass } | ConvertTo-Json | Set-Content "$S\entra-legacy-env.json"
```
Load it in any later session (no `.ps1` file, so no execution policy change):
```powershell
(Get-Content "$S\entra-legacy-env.json" | ConvertFrom-Json).psobject.Properties | ForEach-Object { Set-Item "env:$($_.Name)" $_.Value }
```
List the brownfield IDs (see build-by-hand part 9 step 3 for the import ID formats; bare IDs fail):
```powershell
az rest --url https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies --query 'value[].[id,displayName]' -o tsv
az rest --url https://graph.microsoft.com/v1.0/identity/conditionalAccess/namedLocations --query 'value[].[id,displayName]' -o tsv
az rest --url https://graph.microsoft.com/v1.0/policies/authenticationStrengthPolicies --query "value[?policyType=='custom'].[id,displayName]" -o tsv
az ad group list --query '[].[id,displayName]' -o tsv
```
Write `entra/legacy/imports.tf` with the objects to bring under code, then generate, tidy and plan until only imports show:
```powershell
terraform -chdir=entra/legacy init
terraform -chdir=entra/legacy plan "-var-file=tenants/lab.tfvars" "-generate-config-out=generated.tf"
terraform -chdir=entra/legacy plan "-var-file=tenants/lab.tfvars" "-out=$env:TEMP\legacy.tfplan"
terraform -chdir=entra/legacy apply "$env:TEMP\legacy.tfplan"
terraform -chdir=entra/legacy plan "-var-file=tenants/lab.tfvars" -detailed-exitcode; $LASTEXITCODE   # 0
```
Add `prevent_destroy` to every resource in this root (the Conftest rule also blocks destroys here). The tenant files keep the pipeline's names `lab` and `lab-np`, which `.github/scripts/tf-roots.sh` expects.

### 7.7 Pipeline identities and GitHub settings (build-by-hand parts 10 and 11)
```powershell
$Planner = az ad app create --display-name iac-planner --query appId -o tsv; az ad sp create --id $Planner
$Applier = az ad app create --display-name iac-applier --query appId -o tsv; az ad sp create --id $Applier
New-Fic $Planner github-pull-request pull_request
New-Fic $Applier github-env-nonprod environment:nonprod
New-Fic $Applier github-env-prod environment:prod
Grant-Graph $Planner Directory.Read.All, Policy.Read.All
Grant-Graph $Applier Application.ReadWrite.All, Group.ReadWrite.All, Policy.ReadWrite.ConditionalAccess, Policy.Read.All, `
  Policy.ReadWrite.ApplicationConfiguration, AppRoleAssignment.ReadWrite.All, Directory.Read.All
az login --tenant <tenant-id>      # as bg-admin-01 for consent
az ad app permission admin-consent --id $Planner
az ad app permission admin-consent --id $Applier
az login --tenant <tenant-id>      # back to your own account
foreach ($c in 'tfstate-prod', 'tfstate-nonprod') {
  az role assignment create --assignee-object-id (Get-SpId $Planner) --assignee-principal-type ServicePrincipal --role 'Storage Blob Data Reader' --scope (Get-ContainerScope $c)
  az role assignment create --assignee-object-id (Get-SpId $Applier) --assignee-principal-type ServicePrincipal --role 'Storage Blob Data Contributor' --scope (Get-ContainerScope $c)
}
# Create each state file once (the read-only planner cannot)
foreach ($c in 'tfstate-prod', 'tfstate-nonprod') { foreach ($r in 'entra/platform') {
  terraform "-chdir=$r" init -reconfigure "-backend-config=container_name=$c"
} }
```
Add each wave root to that inner list when you create it.

```powershell
gh variable set AZURE_TENANT_ID   --body <tenant-id>
gh variable set READER_CLIENT_ID  --body $Reader
gh variable set PLANNER_CLIENT_ID --body $Planner
gh variable set APPLIER_CLIENT_ID --body $Applier
gh api -X PUT repos/$O/$R/environments/nonprod
$f = New-TemporaryFile
@{ reviewers = @(@{ type = 'User'; id = [int](gh api users/<reviewer-login> --jq .id) }); prevent_self_review = $false
   deployment_branch_policy = @{ protected_branches = $false; custom_branch_policies = $true } } | ConvertTo-Json -Depth 4 | Set-Content $f
gh api -X PUT repos/$O/$R/environments/prod --input $f; Remove-Item $f
gh api -X POST repos/$O/$R/environments/prod/deployment-branch-policies -f name=main -f type=branch
gh label create change --color 0E8A16
foreach ($s in 'draft', 'assess', 'scheduled', 'implement', 'closed', 'cancelled') { gh label create "change:$s" --color C5DEF5 }
gh label create drift --color D93F0B
```
Branch protection: [git-check-plans-info.md](git-check-plans-info.md), after the first PR has run once. With a second real reviewer, set `prevent_self_review` to `$true`.

### 7.8 First PR and onward (build-by-hand parts 12 to 15)
Section 5's token check must print nothing. Then: a change issue with labels `change` and `change:scheduled` and a `window_start`/`window_end` body, a branch, a PR whose first line is `Change: github:<issue>`, four green checks, merge, approve prod. Write your first wave under `entra/waves/wave-01/` using the lab repo's `entra/waves/wave-00/` as the pattern.

## 8. Checklist

- [ ] PowerShell 7, Git, Azure CLI, GitHub CLI, Terraform, Conftest at the pinned versions; versions in the findings log
- [ ] `$HOME\.iac-secrets` readable by your account only
- [ ] Repo copied with a fresh history; lab material stripped; strip check prints nothing
- [ ] GUID list reviewed; "lab 1" prose reviewed
- [ ] Okta org is Identity Engine; reader token works; write refused (403)
- [ ] `okta-inventory` imports written from your org; plan "No changes"; state in Azure
- [ ] Break-glass group created; policy self-test passes
- [ ] `entra/legacy` imported; plan "No changes"
- [ ] Pipeline identities, federated credentials, Graph permissions, storage roles; each in the permission register
- [ ] GitHub environments, variables, secret, labels, branch protection
- [ ] No `__TOKEN__` left; no CRLF files; no dead links
- [ ] First PR plans green; merge applies nonprod and prod
