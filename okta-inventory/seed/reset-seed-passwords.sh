#!/usr/bin/env bash
# Set one shared password on the active seeded users (docs/okta-seed-spec.md section 2).
# Run 1: the password typed at the seed script's prompt did not match 1Password (pasted more than once).
# Auth: OKTA_ORG_URL and OKTA_API_TOKEN_FILE, as for seed-okta-org.sh. The password is prompted twice,
# never echoed, never stored. Usage: reset-seed-passwords.sh [handle ...]  (default: all but ada.reyes)

set -euo pipefail
: "${OKTA_ORG_URL:?set OKTA_ORG_URL}"; : "${OKTA_API_TOKEN_FILE:?set OKTA_API_TOKEN_FILE}"
AUTH="SSWS $(tr -d '[:space:]' < "$OKTA_API_TOKEN_FILE")"

HANDLES=("$@")
[[ ${#HANDLES[@]} -gt 0 ]] || HANDLES=(ben.okafor cara.lind dev.patel eli.moreno fay.novak gus.tanaka hana.berg)

read -r -s -p "Shared password (min 14 chars, upper, lower, digit): " PW1; echo >&2
read -r -s -p "Same password again: " PW2; echo >&2
[[ "$PW1" == "$PW2" ]] || { echo "Entries differ. Nothing changed." >&2; exit 1; }
[[ ${#PW1} -ge 14 ]] || { echo "Too short. Nothing changed." >&2; exit 1; }
echo "Length: ${#PW1} characters (compare with 1Password)." >&2

BODY=$(jq -cn --arg pw "$PW1" '{credentials:{password:{value:$pw}}}')
unset PW1 PW2
FAILS=0
for h in "${HANDLES[@]}"; do
  login="$h@iaclab.example"
  out=$(curl -sS -X POST "$OKTA_ORG_URL/api/v1/users/$login" -H "Authorization: $AUTH" \
    -H 'Accept: application/json' -H 'Content-Type: application/json' --data "$BODY" -w '\n%{http_code}')
  code=$(echo "$out" | tail -1)
  if [[ "$code" == 200 ]]; then echo "OK    $login" >&2
  else echo "FAIL  $login HTTP $code: $(echo "$out" | sed '$d' | jq -c '{errorSummary,errorCauses}')" >&2; FAILS=$((FAILS+1)); fi
done
unset BODY
echo "Done. Failures: $FAILS" >&2
[[ $FAILS -eq 0 ]]
