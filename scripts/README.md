# scripts: Machine Setup

## What this folder is for

Scripts that set up a machine to work on the lab. Nothing here runs in the pipeline, touches a lab account, or needs a credential. Pipeline helpers live in `.github/scripts/`.

## Files

| File | What it does |
|---|---|
| [bootstrap-iac-lab-vm.sh](bootstrap-iac-lab-vm.sh) | One-shot setup for a dedicated Ubuntu Server 24.04 arm64 workstation VM (virtual machine): OS (operating system) updates, `ufw` firewall allowing SSH (Secure Shell) only, automatic security updates, then the pinned tools installed system-wide in `/usr/local/bin`, each download checksum-verified. Re-runnable: skips tools already at the pinned version. Skips SailPoint CLI and Microsoft365DSC. Full walkthrough: [docs/workstation-vm.md](../docs/workstation-vm.md). |

## How to run it

On the Mac, with the VM reachable as `iac-lab-ubu01`:
```bash
scp scripts/bootstrap-iac-lab-vm.sh iac-lab-ubu01:
ssh -t iac-lab-ubu01 'bash bootstrap-iac-lab-vm.sh'   # -t so sudo can ask for the password
```

## How to change it

- The version variables at the top must match [docs/tool-install.md](../docs/tool-install.md). Change both in the same commit.
- Keep every download checksum-verified, and never add a credential, token or sign-in step: the VM holds no Azure or Okta credentials by design ([docs/workstation-vm.md](../docs/workstation-vm.md), section 6).
- Check syntax before committing: `bash -n scripts/bootstrap-iac-lab-vm.sh`.
