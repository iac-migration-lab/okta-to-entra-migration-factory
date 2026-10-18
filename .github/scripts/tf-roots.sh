#!/usr/bin/env bash
# Plan (and optionally apply) every Entra root for one tenant_key, in dependency order, with Conftest on each plan.
# Usage: tf-roots.sh plan|apply|drift <tenant_key>
#   plan   pull request: plan -lock=false, conftest; a downstream plan that fails while upstream has pending
#          changes is reported as skipped (it reads objects the upstream apply creates)
#   apply  after merge: plan, conftest, apply the saved plan; one retry for Entra replication delays
#   drift  nightly: plan -lock=false; writes drift.md when any root differs
# Roots are included when they have tenants/<tenant_key>.tfvars (entra/legacy exists for prod only).
set -uo pipefail

mode=$1; tk=$2
case "$tk" in
  lab)    container=tfstate-prod ;;
  lab-np) container=tfstate-nonprod ;;
  *) echo "::error::unknown tenant_key $tk"; exit 1 ;;
esac
repo_root=$(pwd); out="$RUNNER_TEMP/tf-$tk"; mkdir -p "$out"
lock=false; [[ $mode == apply ]] && lock=true
summary() { echo "$*" >> "$GITHUB_STEP_SUMMARY"; }
summary "## Entra $mode: tenant_key \`$tk\` (state container \`$container\`)"
summary "| Root | Plan | Conftest | Result |"
summary "|---|---|---|---|"

roots=()
for r in entra/legacy entra/platform entra/waves/*; do [[ -f "$r/tenants/$tk.tfvars" ]] && roots+=("$r"); done

failed=0; pending_upstream=0; drift=0; : > "$out/drift.md"

plan_root() { # $1 root; sets code
  terraform -chdir="$1" plan -input=false -no-color -lock=$lock -detailed-exitcode \
    -var-file="tenants/$tk.tfvars" -out="$out/$2.tfplan" > "$out/$2.plan.txt" 2>&1
  code=$?
}

for root in "${roots[@]}"; do
  name=${root//\//-}
  echo "::group::$root ($tk)"
  terraform -chdir="$root" init -input=false -no-color -reconfigure -lock=$lock -backend-config="container_name=$container" > "$out/$name.init.txt" 2>&1 \
    || { cat "$out/$name.init.txt"; summary "| \`$root\` | init failed | | ❌ |"; failed=1; echo "::endgroup::"; continue; }
  terraform -chdir="$root" validate -no-color || { summary "| \`$root\` | validate failed | | ❌ |"; failed=1; echo "::endgroup::"; continue; }

  plan_root "$root" "$name"
  if [[ $code -eq 1 && $mode == apply ]]; then echo "plan failed; retrying once in 30 s (replication)"; sleep 30; plan_root "$root" "$name"; fi
  cat "$out/$name.plan.txt"
  if [[ $code -eq 1 ]]; then
    if [[ $mode == plan && $pending_upstream -eq 1 && $root == entra/waves/* ]]; then
      summary "| \`$root\` | skipped: reads objects an upstream root has yet to create | | ⏭️ |"
    else
      summary "| \`$root\` | **failed** | | ❌ |"; failed=1
    fi
    echo "::endgroup::"; continue
  fi
  [[ $code -eq 2 && $root != entra/waves/* ]] && pending_upstream=1
  changes=$(grep -E '^Plan:|^No changes' "$out/$name.plan.txt" | head -n1)

  terraform -chdir="$root" show -json "$out/$name.tfplan" > "$out/$name.plan.json"
  printf '{"context":{"root":"%s","tenant_key":"%s"}}' "$root" "$tk" > "$out/$name.context.json"
  if conftest test --no-color --policy "$repo_root/policy" --data "$out/$name.context.json" "$out/$name.plan.json" > "$out/$name.conftest.txt" 2>&1; then
    policy="pass"
  else
    policy="**fail**"; failed=1; cat "$out/$name.conftest.txt"
    { echo; echo "\`$root\` conftest:"; echo '```'; grep -E '^FAIL' "$out/$name.conftest.txt"; echo '```'; } >> "$out/conftest-failures.md"
  fi

  result="✅"
  if [[ $code -eq 2 ]]; then
    case $mode in
      apply)
        if [[ $policy == pass ]]; then
          if ! terraform -chdir="$root" apply -input=false -no-color "$out/$name.tfplan"; then
            echo "apply failed; re-plan and retry once in 30 s (replication)"; sleep 30
            plan_root "$root" "$name"
            if [[ $code -eq 2 ]]; then terraform -chdir="$root" apply -input=false -no-color "$out/$name.tfplan" || { result="❌ apply failed"; failed=1; }
            elif [[ $code -ne 0 ]]; then result="❌ apply failed"; failed=1; fi
          fi
          [[ $result == "✅" ]] && result="✅ applied"
        else
          result="❌ not applied (policy)"
        fi ;;
      drift)
        drift=1; result="⚠️ drift"
        { echo "### \`$root\`"; echo '```'; grep -vE '^\s*$' "$out/$name.plan.txt" | grep -E '^\s*[#~+-]|^Plan:' | head -n 80; echo '```'; } >> "$out/drift.md" ;;
      plan) result="changes" ;;
    esac
  fi
  summary "| \`$root\` | $changes | $policy | $result |"
  echo "::endgroup::"
done

[[ -s "$out/conftest-failures.md" ]] && cat "$out/conftest-failures.md" >> "$GITHUB_STEP_SUMMARY"
[[ -n "${GITHUB_OUTPUT:-}" ]] && { echo "drift=$drift"; echo "drift_file=$out/drift.md"; } >> "$GITHUB_OUTPUT"
exit $failed
