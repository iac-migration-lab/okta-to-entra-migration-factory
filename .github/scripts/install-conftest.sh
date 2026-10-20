#!/usr/bin/env bash
# Conftest pinned and checksum-verified (same version as lab-tools, docs/tool-install.md).
set -euo pipefail
V=0.71.0; F="conftest_${V}_Linux_x86_64.tar.gz"
cd "$RUNNER_TEMP"
curl -fsSLO "https://github.com/open-policy-agent/conftest/releases/download/v$V/$F"
curl -fsSL -o conftest-checksums.txt "https://github.com/open-policy-agent/conftest/releases/download/v$V/checksums.txt"
grep " $F\$" conftest-checksums.txt | sha256sum -c -
tar -xzf "$F" conftest && sudo install conftest /usr/local/bin/conftest
conftest --version
