#!/usr/bin/env bash
# bootstrap-iac-lab-vm.sh
# One-shot setup for a dedicated lab workstation VM: Ubuntu Server 24.04 LTS (arm64). See docs/workstation-vm.md.
# Installs the pinned toolchain system-wide (/usr/local/bin) plus firewall and automatic security updates.
# The standard, no-sudo path is docs/tool-install.md (Linux). Versions here MUST match that file.
# Every download is checksum-verified.
# Run as the normal admin user (not root):   bash bootstrap-iac-lab-vm.sh
# Re-runnable: skips tools already at the pinned version.
#
# Deliberately NOT installed:
#   - Microsoft365DSC (Windows PowerShell module; deferred in run 1 anyway)
#   - SailPoint CLI (deferred in run 1; add later)
# Deliberately NOT configured: any Azure, Okta, or GitHub credential. See docs/workstation-vm.md section 6.

set -euo pipefail

TERRAFORM_VERSION="1.16.4"
AZCLI_VERSION="2.90.0"
PWSH_VERSION="7.6.6"
CONFTEST_VERSION="0.71.0"
NODE_VERSION="24.21.0"
PRISM_VERSION="5.16.0"

ARCH="$(dpkg --print-architecture)"   # expect arm64
[[ "$ARCH" == "arm64" ]] || { echo "Expected arm64, got $ARCH"; exit 1; }
. /etc/os-release
[[ "$VERSION_CODENAME" == "noble" ]] || echo "WARNING: built for Ubuntu 24.04 (noble); this is $VERSION_CODENAME"

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
cd "$WORK"

log() { printf '\n==> %s\n' "$*"; }

log "Base packages and OS updates"
sudo apt-get update
sudo apt-get -y upgrade
sudo apt-get install -y ca-certificates curl gnupg unzip jq git make xz-utils \
  apt-transport-https lsb-release software-properties-common \
  unattended-upgrades fail2ban ufw qemu-guest-agent spice-vdagent

log "Firewall: allow SSH only"
sudo ufw allow OpenSSH
sudo ufw --force enable

log "Unattended security upgrades"
sudo dpkg-reconfigure -f noninteractive unattended-upgrades

# ---------- Terraform (zip + SHA256SUMS + HashiCorp GPG signature) ----------
if ! terraform version 2>/dev/null | grep -q "v${TERRAFORM_VERSION}"; then
  log "Terraform ${TERRAFORM_VERSION}"
  base="https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}"
  curl -fsSLO "${base}/terraform_${TERRAFORM_VERSION}_linux_arm64.zip"
  curl -fsSLO "${base}/terraform_${TERRAFORM_VERSION}_SHA256SUMS"
  curl -fsSLO "${base}/terraform_${TERRAFORM_VERSION}_SHA256SUMS.sig"
  curl -fsSL https://www.hashicorp.com/.well-known/pgp-key.txt | gpg --batch --import
  gpg --batch --verify "terraform_${TERRAFORM_VERSION}_SHA256SUMS.sig" "terraform_${TERRAFORM_VERSION}_SHA256SUMS"
  grep "linux_arm64.zip" "terraform_${TERRAFORM_VERSION}_SHA256SUMS" | sha256sum -c -
  unzip -o "terraform_${TERRAFORM_VERSION}_linux_arm64.zip" terraform
  sudo install -m 0755 terraform /usr/local/bin/terraform
fi

# ---------- Azure CLI (Microsoft apt repo, noble, pinned) ----------
if ! az version 2>/dev/null | grep -q "\"azure-cli\": \"${AZCLI_VERSION}\""; then
  log "Azure CLI ${AZCLI_VERSION}"
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/keyrings/microsoft.gpg >/dev/null
  sudo chmod go+r /etc/apt/keyrings/microsoft.gpg
  sudo tee /etc/apt/sources.list.d/azure-cli.sources >/dev/null <<EOF
Types: deb
URIs: https://packages.microsoft.com/repos/azure-cli/
Suites: noble
Components: main
Architectures: arm64
Signed-by: /etc/apt/keyrings/microsoft.gpg
EOF
  sudo apt-get update
  sudo apt-get install -y "azure-cli=${AZCLI_VERSION}-1~noble"
  sudo apt-mark hold azure-cli
  az config set core.collect_telemetry=false --only-show-errors
fi

# ---------- PowerShell (GitHub release tarball + hashes.sha256) ----------
if ! pwsh -v 2>/dev/null | grep -q "${PWSH_VERSION}"; then
  log "PowerShell ${PWSH_VERSION}"
  base="https://github.com/PowerShell/PowerShell/releases/download/v${PWSH_VERSION}"
  f="powershell-${PWSH_VERSION}-linux-arm64.tar.gz"
  curl -fsSLO "${base}/${f}"
  curl -fsSLO "${base}/hashes.sha256"
  # hashes.sha256 may be UTF-16 with CRLF line endings and a leading * on names (see docs/tool-install.md)
  if head -c2 hashes.sha256 | od -An -tx1 | grep -qiE 'ff fe|fe ff'; then
    iconv -f UTF-16 -t UTF-8 hashes.sha256
  else
    cat hashes.sha256
  fi | tr -d '\r' | grep -F "${f}" | awk -v f="${f}" '{print $1"  "f}' | sha256sum -c -
  sudo rm -rf "/opt/microsoft/powershell/${PWSH_VERSION}"
  sudo mkdir -p "/opt/microsoft/powershell/${PWSH_VERSION}"
  sudo tar -xzf "$f" -C "/opt/microsoft/powershell/${PWSH_VERSION}"
  sudo chmod +x "/opt/microsoft/powershell/${PWSH_VERSION}/pwsh"
  sudo ln -sf "/opt/microsoft/powershell/${PWSH_VERSION}/pwsh" /usr/local/bin/pwsh
fi

# ---------- Conftest (GitHub release + checksums.txt) ----------
if ! conftest --version 2>/dev/null | grep -q "${CONFTEST_VERSION}"; then
  log "Conftest ${CONFTEST_VERSION}"
  base="https://github.com/open-policy-agent/conftest/releases/download/v${CONFTEST_VERSION}"
  f="conftest_${CONFTEST_VERSION}_Linux_arm64.tar.gz"
  curl -fsSLO "${base}/${f}"
  curl -fsSLO "${base}/checksums.txt"
  grep " ${f}\$" checksums.txt | sha256sum -c -
  tar -xzf "$f" conftest
  sudo install -m 0755 conftest /usr/local/bin/conftest
fi

# ---------- Node.js (official tarball + SHASUMS256.txt) ----------
if ! node -v 2>/dev/null | grep -q "v${NODE_VERSION}"; then
  log "Node.js ${NODE_VERSION}"
  base="https://nodejs.org/dist/v${NODE_VERSION}"
  f="node-v${NODE_VERSION}-linux-arm64.tar.xz"
  curl -fsSLO "${base}/${f}"
  curl -fsSLO "${base}/SHASUMS256.txt"
  grep " ${f}\$" SHASUMS256.txt | sha256sum -c -
  sudo rm -rf /opt/node && sudo mkdir -p /opt/node
  sudo tar -xJf "$f" -C /opt/node --strip-components=1
  for b in node npm npx; do sudo ln -sf "/opt/node/bin/$b" "/usr/local/bin/$b"; done
fi

# ---------- Prism mock server (npm, user-local prefix, no sudo npm) ----------
mkdir -p "$HOME/.npm-global"
npm config set prefix "$HOME/.npm-global"
grep -q 'npm-global/bin' "$HOME/.bashrc" || echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> "$HOME/.bashrc"
export PATH="$HOME/.npm-global/bin:$PATH"
if ! prism --version 2>/dev/null | grep -q "${PRISM_VERSION}"; then
  log "Prism ${PRISM_VERSION}"
  npm install -g "@stoplight/prism-cli@${PRISM_VERSION}"
fi

# ---------- GitHub CLI (official apt repo) ----------
if ! command -v gh >/dev/null; then
  log "GitHub CLI"
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
  sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=arm64 signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  sudo apt-get update && sudo apt-get install -y gh
fi

# ---------- Git: credentials held in memory only, 8 hours ----------
git config --global credential.helper 'cache --timeout=28800'
git config --global init.defaultBranch main
git config --global pull.rebase false

log "Installed versions"
terraform version | head -1
az version --query '"azure-cli"' -o tsv
pwsh -v
conftest --version | head -1
node -v
prism --version
gh --version | head -1
echo
echo "Done. Next: reboot, then clone the repo (docs/workstation-vm.md section 5). No credentials were stored by this script."
