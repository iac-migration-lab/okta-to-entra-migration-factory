#!/usr/bin/env bash
# Change gate (docs/change-gate-design.md). Finds the PR, reads its "Change: <system>:<id>" line, asks the
# adapter for a normalized record (state, window), and fails unless state is scheduled or implement and now
# is inside the window. Lab adapter: GitHub Issues (label "change", one "change:<state>" label, window lines).
# Env: GH_TOKEN, REPO, PR_NUMBER (optional; resolved from SHA when empty), SHA.
# CHANGE_REF (optional, e.g. github:17): a manual run with no PR (okta-cutover.yml) names its change directly.
set -euo pipefail

fail() { echo "::error title=Change gate::$1"; echo "**Change gate failed:** $1" >> "$GITHUB_STEP_SUMMARY"; exit 1; }

if [[ -n "${CHANGE_REF:-}" ]]; then
  [[ "$CHANGE_REF" =~ ^[a-z]+:[^[:space:]]+$ ]] || fail "change '$CHANGE_REF' is not <system>:<id>"
  ref=$CHANGE_REF; source_ref="manual run"
else
  if [[ -z "${PR_NUMBER:-}" ]]; then
    PR_NUMBER=$(gh api "repos/$REPO/commits/$SHA/pulls" --jq '.[0].number // empty')
    [[ -n "$PR_NUMBER" ]] || fail "commit $SHA has no pull request; changes reach Entra only through a PR"
  fi
  body=$(gh pr view "$PR_NUMBER" --repo "$REPO" --json body --jq '.body // ""')
  ref=$(grep -oE '^Change:[[:space:]]*[a-z]+:[^[:space:]]+' <<<"$body" | head -n1 | sed -E 's/^Change:[[:space:]]*//' || true)
  [[ -n "$ref" ]] || fail "PR #$PR_NUMBER has no 'Change: <system>:<id>' line"
  source_ref="#$PR_NUMBER"
fi
system=${ref%%:*}; id=${ref#*:}

# Adapters return: id, state, window_start, window_end, url
adapter_github() {
  local issue labels state
  issue=$(gh issue view "$1" --repo "$REPO" --json labels,body,url) || fail "change issue #$1 not found"
  labels=$(jq -r '.labels[].name' <<<"$issue")
  grep -qx 'change' <<<"$labels" || fail "issue #$1 is not labeled 'change'"
  state=$(grep -E '^change:' <<<"$labels" | sed 's/^change://' || true)
  [[ $(grep -c . <<<"$state") -eq 1 ]] || fail "issue #$1 needs exactly one change:<state> label (has: ${state:-none})"
  rec_state=$state
  rec_start=$(jq -r '.body' <<<"$issue" | tr -d '\r' | sed -nE 's/^window_start:[[:space:]]*([^[:space:]]+).*/\1/p' | head -n1)
  rec_end=$(jq -r '.body' <<<"$issue" | tr -d '\r' | sed -nE 's/^window_end:[[:space:]]*([^[:space:]]+).*/\1/p' | head -n1)
  rec_url=$(jq -r '.url' <<<"$issue")
}

case "$system" in
  github) adapter_github "$id" ;;
  *) fail "no adapter for change system '$system' (lab supports github)" ;;
esac

{
  echo "### Change gate"
  echo "| PR | Change | State | Window (UTC) |"
  echo "|---|---|---|---|"
  echo "| $source_ref | [$ref]($rec_url) | $rec_state | ${rec_start:-?} to ${rec_end:-?} |"
} >> "$GITHUB_STEP_SUMMARY"

[[ "$rec_state" == "scheduled" || "$rec_state" == "implement" ]] || fail "change $ref is '$rec_state'; needs scheduled or implement"
[[ -n "$rec_start" && -n "$rec_end" ]] || fail "change $ref has no window_start / window_end"
now=$(date -u +%s)
start=$(date -u -d "$rec_start" +%s) || fail "bad window_start '$rec_start'"
end=$(date -u -d "$rec_end" +%s) || fail "bad window_end '$rec_end'"
(( start <= now && now <= end )) || fail "now ($(date -u +%FT%TZ)) is outside the window of $ref"
echo "Change gate passed: $ref ($rec_state), $source_ref"
