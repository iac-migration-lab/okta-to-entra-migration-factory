# Tool Install (Mac, Linux and Windows)

Versions and download URLs checked 2026-10-01 (Mac) and 2026-10-23 (Linux and Windows) against the vendor release pages listed under Sources.

- **Mac (Apple Silicon):** the sections below, from Design to Notes.
- **Linux (Debian 12 or Ubuntu 24.04):** [Linux](#linux-debian-or-ubuntu).
- **Windows 10 or 11:** [Windows (WSL2)](#windows-wsl2), which installs Ubuntu and then follows the Linux steps.

Same tool versions everywhere. Once installed, every other doc's commands work the same; the few Mac-only commands are in the [table of differences](#commands-that-differ-from-the-mac-docs).

## macOS (Apple Silicon)

### Design
- Pinned binaries go in `~/Projects/okta-to-entra-migration/lab-tools/` (inside the project, git-ignored) and are only on PATH after `source ~/Projects/okta-to-entra-migration/lab-tools/env.sh`. Nothing else on the machine changes (Homebrew Node 26 stays as is).
- Every download is checksum-verified before it is unpacked.
- Azure CLI and PowerShell come from Homebrew (both as formulae), which installs only the current version. They are pinned by `brew pin` (formula) and by the version check below, not by exact install.

### Pinned versions

| Tool | Version | Method | Verified |
|---|---|---|---|
| Terraform CE (Community Edition) | 1.16.4 | releases.hashicorp.com zip + SHA256SUMS | Yes |
| Azure CLI | 2.90.0 | `brew install azure-cli` (Microsoft's documented macOS method) | Yes, method and current version |
| SailPoint CLI (`sail`) | 2.6.0 | GitHub release tarball + checksums file | Yes, release assets, checksum line, and tarball layout (confirmed on install 2026-10-01) |
| Conftest | 0.71.0 | GitHub release tarball + checksums.txt | Yes |
| PowerShell 7 | 7.6.6 | `brew install powershell` (Homebrew formula, not a cask; already installed) | Yes, latest release and formula type (2026-10-01) |
| Microsoft365DSC | 1.26.909.1 | PowerShell Gallery `Install-Module` | Yes, version and PowerShell 7.6+ requirement. UNVERIFIED: macOS support (docs mention Windows only) |
| Node LTS (Long-Term Support) | 24.21.0 | nodejs.org tarball + SHASUMS256.txt | Yes |
| Stoplight Prism | 5.16.0 | `npm install -g @stoplight/prism-cli@5.16.0` (needs Node >= 24.18.0) | Yes |

The Method column is for the Mac. Linux and Windows get the same versions from Linux downloads and Microsoft's and GitHub's apt repositories ([Linux](#linux-debian-or-ubuntu)).

### Install block

Paste the whole block into a terminal. It runs in a child bash shell, so a failure stops the script without closing your terminal.

```bash
bash -euo pipefail <<'EOF'
TF=1.16.4; SAIL=2.6.0; CONFTEST=0.71.0; NODE=24.21.0; PRISM=5.16.0; M365DSC=1.26.909.1
T="$HOME/Projects/okta-to-entra-migration/lab-tools"; mkdir -p "$T/bin" "$T/dl"; cd "$T/dl"

# Terraform CE
curl -fsSLO "https://releases.hashicorp.com/terraform/$TF/terraform_${TF}_darwin_arm64.zip"
curl -fsSLO "https://releases.hashicorp.com/terraform/$TF/terraform_${TF}_SHA256SUMS"
grep " terraform_${TF}_darwin_arm64.zip$" "terraform_${TF}_SHA256SUMS" | shasum -a 256 -c -
unzip -o -q "terraform_${TF}_darwin_arm64.zip" terraform -d "$T/bin"

# SailPoint CLI (binary sits at sail_Darwin_arm64/bin/sail inside the tarball)
curl -fsSLO "https://github.com/sailpoint-oss/sailpoint-cli/releases/download/$SAIL/sail_Darwin_arm64.tar.gz"
curl -fsSLO "https://github.com/sailpoint-oss/sailpoint-cli/releases/download/$SAIL/sail_${SAIL}_checksums.txt"
grep " sail_Darwin_arm64.tar.gz$" "sail_${SAIL}_checksums.txt" | shasum -a 256 -c -
tar -xzf sail_Darwin_arm64.tar.gz -C "$T/bin" --strip-components 2 sail_Darwin_arm64/bin/sail

# Conftest
curl -fsSLO "https://github.com/open-policy-agent/conftest/releases/download/v$CONFTEST/conftest_${CONFTEST}_Darwin_arm64.tar.gz"
curl -fsSL -o conftest_checksums.txt "https://github.com/open-policy-agent/conftest/releases/download/v$CONFTEST/checksums.txt"
grep " conftest_${CONFTEST}_Darwin_arm64.tar.gz$" conftest_checksums.txt | shasum -a 256 -c -
tar -xzf "conftest_${CONFTEST}_Darwin_arm64.tar.gz" -C "$T/bin" conftest

# Node LTS, side by side with Homebrew Node
curl -fsSLO "https://nodejs.org/dist/v$NODE/node-v$NODE-darwin-arm64.tar.gz"
curl -fsSL -o node_SHASUMS256.txt "https://nodejs.org/dist/v$NODE/SHASUMS256.txt"
grep " node-v$NODE-darwin-arm64.tar.gz$" node_SHASUMS256.txt | shasum -a 256 -c -
rm -rf "$T/node" && mkdir -p "$T/node"
tar -xzf "node-v$NODE-darwin-arm64.tar.gz" -C "$T/node" --strip-components 1

# Stoplight Prism, installed into the pinned Node
PATH="$T/node/bin:$PATH" npm install -g "@stoplight/prism-cli@$PRISM"

# Azure CLI (Homebrew installs current; pin stops upgrades)
brew update
brew install azure-cli
brew pin azure-cli

# PowerShell 7 (already present at 7.6.6; installs current if missing)
brew list --formula powershell >/dev/null 2>&1 || brew install powershell

# Microsoft365DSC (UNVERIFIED on macOS)
pwsh -NoProfile -Command "Install-Module Microsoft365DSC -RequiredVersion $M365DSC -Scope CurrentUser -Force"

# Lab PATH, opt-in per terminal
printf 'export PATH="%s/bin:%s/node/bin:$PATH"\n' "$T" "$T" > "$T/env.sh"
echo "Done. Run: source ~/Projects/okta-to-entra-migration/lab-tools/env.sh"
EOF
```

### Version check block

Run this, then paste the full output back.

```bash
source ~/Projects/okta-to-entra-migration/lab-tools/env.sh
echo "terraform: $(terraform -version | head -1)"
echo "az: $(az version --query '"azure-cli"' -o tsv)"
echo "sail: $(sail --version 2>&1 | head -1)"
echo "conftest: $(conftest --version 2>&1 | head -1)"
echo "pwsh: $(pwsh --version)"
echo "Microsoft365DSC: $(pwsh -NoProfile -Command '(Get-Module -ListAvailable Microsoft365DSC | Sort-Object Version -Descending | Select-Object -First 1).Version.ToString()')"
echo "node: $(node --version)"
echo "prism: $(prism --version)"
echo "git: $(git --version)"
```

### Notes
- Microsoft365DSC docs state "Microsoft365DSC requires PowerShell 7.6 or higher" and every reference is Windows. If `Export-M365DSCConfiguration` fails on macOS in Phase 7, run it on a Windows GitHub Actions runner instead. `Update-M365DSCDependencies` is deferred to Phase 7.
- `brew unpin azure-cli` before any deliberate upgrade; record the new version in docs/findings-log.md.

## Linux (Debian or Ubuntu)

For Debian 12 (`bookworm`) and Ubuntu 24.04 (`noble`), on Intel/AMD (`x86_64`) or Arm (`aarch64`) processors. For a dedicated Ubuntu VM (virtual machine) in UTM on the Mac there is also a one-shot alternative, [scripts/bootstrap-iac-lab-vm.sh](../scripts/bootstrap-iac-lab-vm.sh), described in [workstation-vm.md](workstation-vm.md); it installs the same versions system-wide. When a pinned version changes here, change it in that script in the same commit. Ubuntu 24.04 is what the GitHub Actions runners use, so it is the closest match to the pipeline. Windows users follow these same steps inside WSL2 ([Windows](#windows-wsl2) first).

### Step 1: Clone the repo
```bash
mkdir -p ~/Projects && cd ~/Projects
git clone https://github.com/<github-org>/<repo>.git okta-to-entra-migration
```
The install blocks expect the repo at `~/Projects/okta-to-entra-migration`.

### Step 2: System packages, Azure CLI and GitHub CLI (needs sudo)
Paste into a terminal; it asks for your password once.
```bash
bash -euo pipefail <<'EOF'
AZ=2.90.0
# Non-interactive, and never reading this script as input
apt() { sudo DEBIAN_FRONTEND=noninteractive apt-get -y "$@" < /dev/null; }
apt update
apt install curl unzip jq git openssl python3 ca-certificates gnupg lsb-release xz-utils libicu-dev   # libicu: PowerShell needs it

# Azure CLI from Microsoft's apt repository, exact version, held against upgrades
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/keyrings/microsoft.gpg > /dev/null
sudo chmod go+r /etc/apt/keyrings/microsoft.gpg
printf 'Types: deb\nURIs: https://packages.microsoft.com/repos/azure-cli/\nSuites: %s\nComponents: main\nArchitectures: %s\nSigned-by: /etc/apt/keyrings/microsoft.gpg\n' \
  "$(lsb_release -cs)" "$(dpkg --print-architecture)" | sudo tee /etc/apt/sources.list.d/azure-cli.sources > /dev/null
apt update
apt install "azure-cli=${AZ}-1~$(lsb_release -cs)"
sudo apt-mark hold azure-cli

# GitHub CLI from GitHub's apt repository
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
  | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
apt update
apt install gh

echo "Done. Next: the pinned tools block."
EOF
```
The Azure CLI version is exact (`azure-cli=<version>-1~<codename>`, Microsoft's documented pattern) and held with `apt-mark hold`, the equivalent of `brew pin`. `apt-get` runs non-interactively and with `/dev/null` as input: without that, a package that asks a question during install (for example `tzdata` on a minimal Ubuntu) reads the rest of the pasted block as its answer, and the block stops silently. Run `sudo apt-mark unhold azure-cli` before a deliberate upgrade and record the new version in the findings log. If the exact version is missing for your release, `apt-cache madison azure-cli` lists what is there.

### Step 3: Pinned tools (no sudo)
Same versions as the Mac block, checksum-verified, into `lab-tools/` inside the repo. Works on Intel/AMD and Arm.
```bash
bash -euo pipefail <<'EOF'
TF=1.16.4; SAIL=2.6.0; CONFTEST=0.71.0; NODE=24.21.0; PRISM=5.16.0; PWSH=7.6.6
case "$(uname -m)" in
  x86_64)  A_TF=amd64; A_GH=x86_64; A_NODE=x64;   A_PWSH=x64 ;;
  aarch64) A_TF=arm64; A_GH=arm64;  A_NODE=arm64; A_PWSH=arm64 ;;
  *) echo "Unsupported CPU $(uname -m)"; exit 1 ;;
esac
T="$HOME/Projects/okta-to-entra-migration/lab-tools"; mkdir -p "$T/bin" "$T/dl"; cd "$T/dl"

# Terraform CE
curl -fsSLO "https://releases.hashicorp.com/terraform/$TF/terraform_${TF}_linux_${A_TF}.zip"
curl -fsSLO "https://releases.hashicorp.com/terraform/$TF/terraform_${TF}_SHA256SUMS"
grep " terraform_${TF}_linux_${A_TF}.zip$" "terraform_${TF}_SHA256SUMS" | sha256sum -c -
unzip -o -q "terraform_${TF}_linux_${A_TF}.zip" terraform -d "$T/bin"

# SailPoint CLI (binary sits at sail_Linux_<arch>/sail inside the tarball)
curl -fsSLO "https://github.com/sailpoint-oss/sailpoint-cli/releases/download/$SAIL/sail_Linux_${A_GH}.tar.gz"
curl -fsSLO "https://github.com/sailpoint-oss/sailpoint-cli/releases/download/$SAIL/sail_${SAIL}_checksums.txt"
grep " sail_Linux_${A_GH}.tar.gz$" "sail_${SAIL}_checksums.txt" | sha256sum -c -
tar -xzf "sail_Linux_${A_GH}.tar.gz" -C "$T/bin" --strip-components 1 "sail_Linux_${A_GH}/sail"

# Conftest
curl -fsSLO "https://github.com/open-policy-agent/conftest/releases/download/v$CONFTEST/conftest_${CONFTEST}_Linux_${A_GH}.tar.gz"
curl -fsSL -o conftest_checksums.txt "https://github.com/open-policy-agent/conftest/releases/download/v$CONFTEST/checksums.txt"
grep " conftest_${CONFTEST}_Linux_${A_GH}.tar.gz$" conftest_checksums.txt | sha256sum -c -
tar -xzf "conftest_${CONFTEST}_Linux_${A_GH}.tar.gz" -C "$T/bin" conftest

# Node LTS
curl -fsSLO "https://nodejs.org/dist/v$NODE/node-v$NODE-linux-${A_NODE}.tar.gz"
curl -fsSL -o node_SHASUMS256.txt "https://nodejs.org/dist/v$NODE/SHASUMS256.txt"
grep " node-v$NODE-linux-${A_NODE}.tar.gz$" node_SHASUMS256.txt | sha256sum -c -
rm -rf "$T/node" && mkdir -p "$T/node"
tar -xzf "node-v$NODE-linux-${A_NODE}.tar.gz" -C "$T/node" --strip-components 1

# Stoplight Prism, installed into the pinned Node
PATH="$T/node/bin:$PATH" npm install -g "@stoplight/prism-cli@$PRISM"

# PowerShell 7 (tarball; the hashes file is UTF-16 with Windows line endings and a leading * on names)
curl -fsSLO "https://github.com/PowerShell/PowerShell/releases/download/v$PWSH/powershell-$PWSH-linux-${A_PWSH}.tar.gz"
curl -fsSL -o pwsh_hashes.sha256 "https://github.com/PowerShell/PowerShell/releases/download/v$PWSH/hashes.sha256"
iconv -f UTF-16 -t UTF-8 pwsh_hashes.sha256 | tr -d '\r' | grep " \*powershell-$PWSH-linux-${A_PWSH}.tar.gz$" | sha256sum -c -
rm -rf "$T/pwsh" && mkdir -p "$T/pwsh"
tar -xzf "powershell-$PWSH-linux-${A_PWSH}.tar.gz" -C "$T/pwsh"
chmod +x "$T/pwsh/pwsh" && ln -sf "$T/pwsh/pwsh" "$T/bin/pwsh"

# Lab PATH, opt-in per terminal
printf 'export PATH="%s/bin:%s/node/bin:$PATH"\n' "$T" "$T" > "$T/env.sh"
echo "Done. Run: source ~/Projects/okta-to-entra-migration/lab-tools/env.sh"
EOF
```

**Tested 2026-10-23** in clean containers, both blocks exactly as written: Debian 12 (Arm), Ubuntu 24.04 (Arm), Ubuntu 24.04 (x86_64). Result on all three: Terraform 1.16.4, Azure CLI 2.90.0, sail 2.6.0, Conftest 0.71.0, PowerShell 7.6.6, Node 24.21.0, Prism 5.16.0, gh 2.103.0; all five checksums OK. Not tested: Debian on x86_64, and a real WSL2 install on Windows.

### Step 4: Check versions
Run the [version check block](#version-check-block); it works unchanged. Add `gh --version` and `jq --version`.

**Microsoft365DSC** (Lab Phase 7 only) is not installed on Linux: it is Windows-first. Run it on Windows (see below) or on a Windows GitHub Actions runner.

### Commands that differ from the Mac docs

| Mac command (in the docs) | Linux | Windows (Ubuntu terminal in WSL2) |
|---|---|---|
| `pbpaste > file` (save the clipboard to a file) | `xclip -selection clipboard -o > file` (X11) or `wl-paste > file` (Wayland); install `xclip` or `wl-clipboard` | `powershell.exe -NoProfile -Command Get-Clipboard \| tr -d '\r' > file` |
| `... \| pbcopy` (copy to the clipboard) | `... \| xclip -selection clipboard` or `... \| wl-copy` | `... \| clip.exe` |
| `brew install gh jq` | Done in step 2 | Done in step 2 |
| `open <url>` | `xdg-open <url>` | `wslview <url>` |
| `az login` opens a browser | Same | Same, through `wslview`. UNVERIFIED: if no browser opens, copy the URL it prints into a Windows browser |
| `shasum -a 256 -c -` | `sha256sum -c -` | `sha256sum -c -` |

To copy a password without a trailing newline, strip it first: `tr -d '\n' < file | <copy command>`. Everything else (Terraform, `az`, `gh`, `curl`, `jq`, `openssl`, `chmod`, the repo scripts) is identical.

## Windows (WSL2)

### Why WSL2, not native Windows
Every script in this repo (seed, reader check, snapshot export, policy self-test, the pipeline scripts) is a bash script, and the secret files rely on Linux file permissions (`chmod 600`). WSL2 (Windows Subsystem for Linux, version 2) runs a real Ubuntu Linux inside Windows, so you follow the Linux steps above inside it. Native PowerShell alone is not supported: Terraform and the Azure CLI would work, but none of the scripts would.

### Step 1: Install WSL2 and Ubuntu 24.04
In **PowerShell, run as Administrator**:
```powershell
wsl --install -d Ubuntu-24.04
```
Restart when asked. Ubuntu opens and asks for a Linux user name and password (this password is for `sudo` inside Ubuntu; store it in your password manager). Check it is version 2:
```powershell
wsl -l -v      # VERSION column must say 2
```
From now on, run every command in the **Ubuntu** terminal (Start menu → Ubuntu 24.04, or Windows Terminal → Ubuntu), not in PowerShell.

### Step 2: Keep everything inside the Linux file system
- Clone the repo to `~/Projects/okta-to-entra-migration` **inside Ubuntu**, not under `/mnt/c/...` (the Windows C: drive). On `/mnt/c`, `chmod 600` does not protect files, scripts can get Windows line endings, and Terraform runs slowly.
- Keep `~/.okta-lab/` (keys, passwords) inside Ubuntu too.
- To edit files, install VS Code (Visual Studio Code) on Windows with the **WSL** extension, then run `code .` from the repo folder in Ubuntu.

### Step 3: Browser sign-ins through Windows
So that `az login` and `gh auth login` open your Windows browser:
```bash
sudo apt-get update && sudo apt-get install -y wslu < /dev/null
grep -q 'BROWSER=wslview' ~/.bashrc || echo 'export BROWSER=wslview' >> ~/.bashrc
```
Close and reopen the Ubuntu terminal.

### Step 4: Follow the Linux steps
Do [Linux steps 1 to 4](#linux-debian-or-ubuntu) in the Ubuntu terminal. Use the Windows column of the [commands table](#commands-that-differ-from-the-mac-docs). For test sign-ins, use a private window in your Windows browser (Edge InPrivate `Ctrl+Shift+N`, or Chrome Incognito).

### Microsoft365DSC (Lab Phase 7 only, optional now)
A Windows-first module, so install it in **native Windows PowerShell 7**, not in Ubuntu:
```powershell
winget install --id Microsoft.PowerShell --version 7.6.6 --exact
pwsh -NoProfile -Command "Install-Module Microsoft365DSC -RequiredVersion 1.26.909.1 -Scope CurrentUser -Force"
```

### Line endings
The repo's `.gitattributes` makes Git check out text files with Linux line endings (LF). If a script fails with `$'\r': command not found`, it was saved with Windows line endings: clone inside Ubuntu (step 2), or fix one file with `sed -i 's/\r$//' <file>`.

## Sources
- Terraform releases: https://releases.hashicorp.com/terraform/1.16.4/
- Azure CLI on macOS: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-macos
- SailPoint CLI install: https://developer.sailpoint.com/docs/tools/cli/
- SailPoint CLI releases: https://github.com/sailpoint-oss/sailpoint-cli/releases/tag/2.6.0
- Conftest releases: https://github.com/open-policy-agent/conftest/releases/tag/v0.71.0
- PowerShell releases: https://github.com/PowerShell/PowerShell/releases/tag/v7.6.6
- Microsoft365DSC prerequisites: https://microsoft365dsc.com/user-guide/get-started/prerequisites/
- Microsoft365DSC on PowerShell Gallery: https://www.powershellgallery.com/packages/Microsoft365DSC
- Node.js release index: https://nodejs.org/dist/index.json
- Prism on npm: https://www.npmjs.com/package/@stoplight/prism-cli
- WSL install: https://learn.microsoft.com/en-us/windows/wsl/install
- Azure CLI on Linux (apt): https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-linux
- GitHub CLI on Linux: https://github.com/cli/cli/blob/trunk/docs/install_linux.md
- PowerShell 7.6.6 release hashes: https://github.com/PowerShell/PowerShell/releases/tag/v7.6.6
