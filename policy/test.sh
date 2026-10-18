#!/usr/bin/env bash
# Policy self-test: the pass fixture must pass, the fail fixture must fail all three rules.
set -uo pipefail
cd "$(dirname "$0")"
conftest test --policy . --data fixtures/legacy-context.json fixtures/pass-plan.json || { echo "FAIL: pass fixture denied"; exit 1; }
out=$(conftest test --no-color --policy . --data fixtures/legacy-context.json fixtures/fail-plan.json) && { echo "FAIL: fail fixture passed"; exit 1; }
echo "$out"
for want in "exclude bg-ca-exclusion" "start report-only" "must not be destroyed"; do
  grep -q "$want" <<<"$out" || { echo "FAIL: missing denial: $want"; exit 1; }
done
echo "policy self-test OK"
