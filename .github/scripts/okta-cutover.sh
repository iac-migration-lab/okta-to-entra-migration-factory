#!/usr/bin/env bash
# Okta cutover as iac-okta-cutover (private key JWT, okta.apps.manage, App Administrator on the wave's apps).
# remove: delete the app's group assignments, so users reach the app only through Entra (wave-01 plan section 2).
# restore: put them back with their priorities (rollback). list: show them, no change.
# Logs the assigned groups before and after to stdout and the job summary. App and group IDs: .github/okta-cutover-apps.json.
# Env: OKTA_ORG_URL, OKTA_CLIENT_ID, OKTA_KEY_ID, OKTA_PRIVATE_KEY_FILE, APP (app label), ACTION (list|remove|restore).
set -euo pipefail

MAP=${MAP:-$(dirname "$0")/../okta-cutover-apps.json}
SUMMARY=${GITHUB_STEP_SUMMARY:-/dev/null}
fail() { echo "::error title=Okta cutover::$1"; echo "**Okta cutover failed:** $1" >> "$SUMMARY"; exit 1; }

app_id=$(jq -r --arg a "$APP" '.[$a].app_id // empty' "$MAP")
[[ -n "$app_id" ]] || fail "app '$APP' is not in $(basename "$MAP")"
[[ "$ACTION" =~ ^(list|remove|restore)$ ]] || fail "action must be list, remove or restore"

b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }
now=$(date +%s)
header=$(jq -cn --arg kid "$OKTA_KEY_ID" '{alg:"RS256",typ:"JWT",kid:$kid}' | b64url)
payload=$(jq -cn --arg c "$OKTA_CLIENT_ID" --arg aud "$OKTA_ORG_URL/oauth2/v1/token" --argjson iat "$now" \
  --argjson exp $((now + 300)) --arg jti "$(openssl rand -hex 16)" '{iss:$c,sub:$c,aud:$aud,iat:$iat,exp:$exp,jti:$jti}' | b64url)
sig=$(printf '%s' "$header.$payload" | openssl dgst -sha256 -sign "$OKTA_PRIVATE_KEY_FILE" | b64url)
resp=$(curl -sS -w "\n%{http_code}" -X POST "$OKTA_ORG_URL/oauth2/v1/token" -H 'Accept: application/json' \
  --data-urlencode grant_type=client_credentials --data-urlencode scope=okta.apps.manage \
  --data-urlencode client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer \
  --data-urlencode "client_assertion=$header.$payload.$sig")
http=${resp##*$'\n'}; resp=${resp%$'\n'*}
TOKEN=$(jq -r '.access_token // empty' <<<"$resp" 2>/dev/null || true)
# A deactivated service app cannot get a token: an admin activates iac-okta-cutover for the window.
[[ -n "$TOKEN" ]] || fail "token request failed (HTTP $http $(jq -r '[.error, .errorCode, .errorSummary, .error_description] | map(select(.)) | join(" ")' <<<"$resp" 2>/dev/null)); is iac-okta-cutover active?"

okta() { curl -sS -o "$RUNNER_TMP/body" -w '%{http_code}' -H "Authorization: Bearer $TOKEN" -H 'Accept: application/json' -H 'Content-Type: application/json' "$@"; }
RUNNER_TMP=$(mktemp -d); trap 'rm -rf "$RUNNER_TMP"; unset TOKEN' EXIT

assigned() {
  local code; code=$(okta "$OKTA_ORG_URL/api/v1/apps/$app_id/groups?limit=200")
  [[ $code == 200 ]] || fail "list groups of $APP: HTTP $code $(jq -r '.errorSummary // empty' "$RUNNER_TMP/body")"
  jq -r --slurpfile m "$MAP" --arg a "$APP" \
    '.[] | .id as $g | (($m[0][$a].groups[] | select(.id == $g) | .name) // $g) + " (priority \(.priority // "-"))"' "$RUNNER_TMP/body"
}

before=$(assigned)
echo "Before: ${before:-none}"
{ echo "### Okta cutover: \`$APP\` $ACTION"; echo; echo "| | Assigned groups |"; echo "|---|---|"; echo "| Before | $(tr '\n' ';' <<<"${before:-none}" | sed 's/;$//; s/;/, /g') |"; } >> "$SUMMARY"

i=0
while read -r gid name; do
  case $ACTION in
    remove)  code=$(okta -X DELETE "$OKTA_ORG_URL/api/v1/apps/$app_id/groups/$gid") ;;
    restore) code=$(okta -X PUT "$OKTA_ORG_URL/api/v1/apps/$app_id/groups/$gid" -d "{\"priority\":$i}") ;;
    list)    code=skip ;;
  esac
  [[ $code =~ ^(200|204|skip)$ ]] || fail "$ACTION $name on $APP: HTTP $code $(jq -r '.errorSummary // empty' "$RUNNER_TMP/body" 2>/dev/null)"
  [[ $code == skip ]] || echo "$ACTION $name: HTTP $code"
  i=$((i + 1))
done < <(jq -r --arg a "$APP" '.[$a].groups[] | "\(.id) \(.name)"' "$MAP")

after=$(assigned)
echo "After: ${after:-none}"
echo "| After | $(tr '\n' ';' <<<"${after:-none}" | sed 's/;$//; s/;/, /g') |" >> "$SUMMARY"
