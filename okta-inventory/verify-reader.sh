#!/usr/bin/env bash
# Read-only check of the iac-okta-reader identity: private key JWT -> access token -> counts per object type.
# No SSWS token. Prints counts only, never the token or user details.
# Env: OKTA_ORG_URL, OKTA_CLIENT_ID, OKTA_KEY_ID, OKTA_PRIVATE_KEY_FILE (outside the repo).

set -euo pipefail
: "${OKTA_ORG_URL:?}"; : "${OKTA_CLIENT_ID:?}"; : "${OKTA_KEY_ID:?}"; : "${OKTA_PRIVATE_KEY_FILE:?}"
SCOPES="okta.apps.read okta.users.read okta.groups.read okta.policies.read okta.authorizationServers.read okta.idps.read okta.schemas.read"

b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }
now=$(date +%s)
header=$(jq -cn --arg kid "$OKTA_KEY_ID" '{alg:"RS256",typ:"JWT",kid:$kid}' | b64url)
payload=$(jq -cn --arg c "$OKTA_CLIENT_ID" --arg aud "$OKTA_ORG_URL/oauth2/v1/token" --argjson iat "$now" \
  --argjson exp $((now + 300)) --arg jti "$(openssl rand -hex 16)" '{iss:$c,sub:$c,aud:$aud,iat:$iat,exp:$exp,jti:$jti}' | b64url)
sig=$(printf '%s' "$header.$payload" | openssl dgst -sha256 -sign "$OKTA_PRIVATE_KEY_FILE" | b64url)
resp=$(curl -sS -X POST "$OKTA_ORG_URL/oauth2/v1/token" -H 'Accept: application/json' \
  -H 'Content-Type: application/x-www-form-urlencoded' --data-urlencode grant_type=client_credentials \
  --data-urlencode "scope=$SCOPES" \
  --data-urlencode client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer \
  --data-urlencode "client_assertion=$header.$payload.$sig")
TOKEN=$(echo "$resp" | jq -r '.access_token // empty')
[[ -n "$TOKEN" ]] || { echo "Token request failed: $(echo "$resp" | jq -c '{error,error_description}')" >&2; exit 1; }
echo "Token OK (type $(echo "$resp" | jq -r .token_type), scopes: $(echo "$resp" | jq -r .scope))"

get() { curl -sS "$OKTA_ORG_URL$1" -H "Authorization: Bearer $TOKEN" -H 'Accept: application/json' -w '\n%{http_code}'; }
count() { # label path jq-filter
  local out code; out=$(get "$2"); code=$(echo "$out" | tail -1)
  if [[ "$code" == 200 ]]; then printf '%-28s %s\n' "$1" "$(echo "$out" | sed '$d' | jq -c "$3")"
  else printf '%-28s HTTP %s %s\n' "$1" "$code" "$(echo "$out" | sed '$d' | jq -r '.errorSummary // empty')"; fi
}
count users             "/api/v1/users?limit=200&search=status%20pr" 'group_by(.status)|map({(.[0].status):length})|add'
count groups            "/api/v1/groups?limit=200"         '{total:length, custom:[.[]|select(.type=="OKTA_GROUP")|.profile.name]}'
count apps              "/api/v1/apps?limit=200"           '{total:length, seeded:[.[]|select(.label|test("^iac-|^Slack$"))|.label]}'
count network-zones     "/api/v1/zones"                    '[.[]|.name]'
for t in PASSWORD OKTA_SIGN_ON ACCESS_POLICY MFA_ENROLL; do
  count "policies $t"   "/api/v1/policies?type=$t"         '[.[]|.name]'
done
count authorization-servers "/api/v1/authorizationServers" '[.[]|.name]'
count identity-providers    "/api/v1/idps"                 'length'
out=$(curl -sS -X POST "$OKTA_ORG_URL/api/v1/groups" -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"profile":{"name":"iac-reader-write-test","description":"must fail"}}' -w '\n%{http_code}')
printf '%-28s HTTP %s (expect 403)\n' "write-test" "$(echo "$out" | tail -1)"
unset TOKEN
