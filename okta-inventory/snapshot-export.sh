#!/usr/bin/env bash
# Nightly Okta export as iac-okta-reader (private key JWT, read scopes only).
#   Counts only  -> $COUNTS_FILE (committed to Git)
#   Users, group members, app assignments (personal data) -> $EXPORT_DIR (uploaded to Azure Blob, never Git)
# Env: OKTA_ORG_URL, OKTA_CLIENT_ID, OKTA_KEY_ID, OKTA_PRIVATE_KEY_FILE, COUNTS_FILE, EXPORT_DIR

set -euo pipefail
: "${OKTA_ORG_URL:?}"; : "${OKTA_CLIENT_ID:?}"; : "${OKTA_KEY_ID:?}"; : "${OKTA_PRIVATE_KEY_FILE:?}"
: "${COUNTS_FILE:?}"; : "${EXPORT_DIR:?}"
SCOPES="okta.apps.read okta.users.read okta.groups.read okta.policies.read okta.authorizationServers.read okta.networkZones.read"

b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }
now=$(date +%s)
header=$(jq -cn --arg kid "$OKTA_KEY_ID" '{alg:"RS256",typ:"JWT",kid:$kid}' | b64url)
payload=$(jq -cn --arg c "$OKTA_CLIENT_ID" --arg aud "$OKTA_ORG_URL/oauth2/v1/token" --argjson iat "$now" \
  --argjson exp $((now + 300)) --arg jti "$(openssl rand -hex 16)" '{iss:$c,sub:$c,aud:$aud,iat:$iat,exp:$exp,jti:$jti}' | b64url)
sig=$(printf '%s' "$header.$payload" | openssl dgst -sha256 -sign "$OKTA_PRIVATE_KEY_FILE" | b64url)
TOKEN=$(curl -sS -X POST "$OKTA_ORG_URL/oauth2/v1/token" -H 'Accept: application/json' \
  -H 'Content-Type: application/x-www-form-urlencoded' --data-urlencode grant_type=client_credentials \
  --data-urlencode "scope=$SCOPES" \
  --data-urlencode client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer \
  --data-urlencode "client_assertion=$header.$payload.$sig" | jq -r '.access_token // empty')
[[ -n "$TOKEN" ]] || { echo "Okta token request failed" >&2; exit 1; }

# get PATH -> JSON array, following Link rel="next" pagination
get() {
  local url="$OKTA_ORG_URL$1" out="[]" page hdr
  hdr=$(mktemp)
  while [[ -n "$url" ]]; do
    page=$(curl -sS -f -D "$hdr" "$url" -H "Authorization: Bearer $TOKEN" -H 'Accept: application/json')
    out=$(jq -c --argjson p "$page" '. + $p' <<< "$out")
    url=$(grep -i '^link:.*rel="next"' "$hdr" | sed -E 's/.*<([^>]+)>; rel="next".*/\1/' | tr -d '\r' || true)
  done
  rm -f "$hdr"; echo "$out"
}

mkdir -p "$EXPORT_DIR"
users=$(get '/api/v1/users?limit=200&search=status%20pr')
groups=$(get '/api/v1/groups?limit=200')
apps=$(get '/api/v1/apps?limit=200')
echo "$users" > "$EXPORT_DIR/users.json"

members="{}"
for g in $(jq -r '.[] | select(.type=="OKTA_GROUP") | .id' <<< "$groups"); do
  members=$(jq -c --arg g "$g" --argjson m "$(get "/api/v1/groups/$g/users?limit=200" | jq -c '[.[].id]')" '. + {($g): $m}' <<< "$members")
done
echo "$members" > "$EXPORT_DIR/group-members.json"

assign="{}"
for a in $(jq -r '.[].id' <<< "$apps"); do
  assign=$(jq -c --arg a "$a" --argjson u "$(get "/api/v1/apps/$a/users?limit=200" | jq -c '[.[] | {id, scope}]')" \
    --argjson g "$(get "/api/v1/apps/$a/groups?limit=200" | jq -c '[.[].id]')" '. + {($a): {users: $u, groups: $g}}' <<< "$assign")
done
echo "$assign" > "$EXPORT_DIR/app-assignments.json"

zones=$(get /api/v1/zones)
pol() { get "/api/v1/policies?type=$1" | jq '[.[] | select(.system != true)] | length'; }
authz=$(get /api/v1/authorizationServers)

# Counts only. No names of people, no IDs.
{
  echo "# Okta inventory counts"
  echo
  echo "Written by \`.github/workflows/snapshot.yml\` from org \`${OKTA_ORG_URL#https://}\` as \`iac-okta-reader\`. Counts only; user and assignment data go to Azure Blob \`okta-exports\`, never to Git. Committed only when a count changes."
  echo
  echo "| Object | Count |"
  echo "|---|---|"
  jq -r 'group_by(.status)[] | "| Users \(.[0].status) | \(length) |"' <<< "$users"
  echo "| Groups (custom) | $(jq '[.[] | select(.type=="OKTA_GROUP")] | length' <<< "$groups") |"
  echo "| Apps (visible to reader) | $(jq 'length' <<< "$apps") |"
  echo "| App group assignments | $(jq '[.[].groups | length] | add // 0' <<< "$assign") |"
  echo "| Network zones (all) | $(jq 'length' <<< "$zones") |"
  echo "| Password policies (non-system) | $(pol PASSWORD) |"
  echo "| Global session policies (non-system) | $(pol OKTA_SIGN_ON) |"
  echo "| Authentication policies (non-system) | $(pol ACCESS_POLICY) |"
  echo "| Authorization servers | $(jq 'length' <<< "$authz") |"
} > "$COUNTS_FILE"
unset TOKEN
echo "Export written: $(ls "$EXPORT_DIR" | tr '\n' ' ')"
