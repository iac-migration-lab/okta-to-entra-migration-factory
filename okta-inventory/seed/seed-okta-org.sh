#!/usr/bin/env bash
# Seed the lab Okta org per docs/okta-seed-spec.md.
# One-off, run by the owner. Not Terraform: the seeded org is the brownfield source Phase 1 imports.
#
# Auth, one of:
#   OKTA_API_TOKEN_FILE    SSWS API token file outside the repo (run 1 shortcut; Not OK in production,
#                          see docs/permission-register.md), or
#   OKTA_CLIENT_ID + OKTA_KEY_ID + OKTA_PRIVATE_KEY_FILE   service app with private key JWT.
# Always: OKTA_ORG_URL  https://integrator-2631921.okta.com
# Default is a dry run (reads only, prints planned writes). Pass --apply to write.
# The shared user password is prompted for and never echoed or stored.

set -euo pipefail

APPLY=0
[[ "${1:-}" == "--apply" ]] && APPLY=1

: "${OKTA_ORG_URL:?set OKTA_ORG_URL}"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SECRET_FILE="${OKTA_API_TOKEN_FILE:-${OKTA_PRIVATE_KEY_FILE:?set OKTA_API_TOKEN_FILE or OKTA_PRIVATE_KEY_FILE}}"
KEY_REAL="$(cd "$(dirname "$SECRET_FILE")" && pwd)/$(basename "$SECRET_FILE")"
case "$KEY_REAL" in "$REPO_ROOT"/*) echo "Refusing: secret file is inside the repo." >&2; exit 1 ;; esac

SCOPES="okta.users.manage okta.groups.manage okta.apps.manage okta.policies.manage okta.networkZones.manage okta.authorizationServers.manage"
SAML_ACS="https://sptest.iamshowcase.com/acs"
SAML_AUD="IAMShowcase"
OIDC_REDIRECT="https://oidcdebugger.com/debug"
LOGIN_DOMAIN="iaclab.example"
MAIL_BASE="la-migration-lab"
MAIL_DOMAIN="outlook.com"

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
: > "$TMP/fails"

b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }

get_token() {
  if [[ -n "${OKTA_API_TOKEN_FILE:-}" ]]; then
    AUTH="SSWS $(tr -d '[:space:]' < "$OKTA_API_TOKEN_FILE")"
    echo '{"scope":"(SSWS token: acts with the creating admin'"'"'s roles)"}' > "$TMP/token.json"
    return
  fi
  : "${OKTA_CLIENT_ID:?set OKTA_CLIENT_ID}"; : "${OKTA_KEY_ID:?set OKTA_KEY_ID}"
  local now header payload unsigned sig
  now=$(date +%s)
  header=$(jq -cn --arg kid "$OKTA_KEY_ID" '{alg:"RS256",typ:"JWT",kid:$kid}' | b64url)
  payload=$(jq -cn --arg c "$OKTA_CLIENT_ID" --arg aud "$OKTA_ORG_URL/oauth2/v1/token" \
    --argjson iat "$now" --argjson exp $((now + 300)) --arg jti "$(openssl rand -hex 16)" \
    '{iss:$c,sub:$c,aud:$aud,iat:$iat,exp:$exp,jti:$jti}' | b64url)
  unsigned="$header.$payload"
  sig=$(printf '%s' "$unsigned" | openssl dgst -sha256 -sign "$OKTA_PRIVATE_KEY_FILE" | b64url)
  curl -sS -X POST "$OKTA_ORG_URL/oauth2/v1/token" \
    -H 'Accept: application/json' -H 'Content-Type: application/x-www-form-urlencoded' \
    --data-urlencode grant_type=client_credentials --data-urlencode "scope=$SCOPES" \
    --data-urlencode client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer \
    --data-urlencode "client_assertion=$unsigned.$sig" > "$TMP/token.json"
  TOKEN=$(jq -r '.access_token // empty' "$TMP/token.json")
  if [[ -z "$TOKEN" ]]; then
    echo "Token request failed:" >&2; jq '{error, error_description}' "$TMP/token.json" >&2; exit 1
  fi
  AUTH="Bearer $TOKEN"
}

# api METHOD PATH [JSON]  -> body on stdout; HTTP code in $TMP/code
api() {
  local method=$1 path=$2 body=${3:-}
  local args=(-sS -X "$method" "$OKTA_ORG_URL$path" -H "Authorization: $AUTH"
    -H 'Accept: application/json' -H 'Content-Type: application/json' -o "$TMP/body" -w '%{http_code}')
  [[ -n "$body" ]] && args+=(--data "$body")
  curl "${args[@]}" > "$TMP/code"
  local code; code=$(cat "$TMP/code")
  if [[ "$code" == 429 ]]; then sleep 10; api "$@"; return; fi
  cat "$TMP/body"
}
code() { cat "$TMP/code"; }

# write METHOD PATH JSON LABEL -> prints created object, or DRYRUN placeholder
write() {
  local method=$1 path=$2 body=$3 label=$4
  if [[ $APPLY -eq 0 ]]; then
    echo "PLAN  $method $path  ($label)" >&2
    echo "{\"id\":\"DRYRUN-$label\",\"credentials\":{\"oauthClient\":{\"client_id\":\"DRYRUN-$label\"}}}"
    return
  fi
  local out; out=$(api "$method" "$path" "$body")
  local c; c=$(code)
  if [[ "$c" =~ ^2 ]]; then
    echo "OK    $method $path  ($label)" >&2
  else
    echo "FAIL  $method $path  ($label) HTTP $c: $(echo "$out" | jq -c '{errorCode,errorSummary,errorCauses}' 2>/dev/null || echo "$out")" >&2
    echo "$label" >> "$TMP/fails"
  fi
  echo "$out"
}

# find_id PATH JQ_FILTER -> id or empty
find_id() { { api GET "$1" | jq -r "$2 | .id" 2>/dev/null || true; } | head -n1; }

echo "Mode: $([[ $APPLY -eq 1 ]] && echo APPLY || echo DRY RUN)  Org: $OKTA_ORG_URL" >&2
get_token
echo "Auth OK (scopes: $(jq -r .scope "$TMP/token.json"))" >&2

# ---------- 1. Groups ----------
ensure_group() {
  local name=$1 desc=$2 id
  id=$(find_id "/api/v1/groups?q=$name" ".[] | select(.profile.name==\"$name\")")
  if [[ -z "$id" ]]; then
    id=$(write POST /api/v1/groups "$(jq -cn --arg n "$name" --arg d "$desc" '{profile:{name:$n,description:$d}}')" "group $name" | jq -r .id)
  else echo "SKIP  group $name exists" >&2; fi
  echo "$id"
}
GID_IT=$(ensure_group IT "IT staff")
GID_CS=$(ensure_group CustServ "Customer service")
GID_FIN=$(ensure_group Finance "Finance")
ALL_GROUPS=$(jq -cn --arg a "$GID_IT" --arg b "$GID_CS" --arg c "$GID_FIN" '[$a,$b,$c]')

# ---------- 2. Network zone ----------
ZONE_ID=$(find_id "/api/v1/zones" ".[] | select(.name==\"iac-zone-office\")")
if [[ -z "$ZONE_ID" ]]; then
  ZONE_ID=$(write POST /api/v1/zones '{"type":"IP","name":"iac-zone-office","usage":"POLICY","gateways":[{"type":"CIDR","value":"203.0.113.0/24"}],"proxies":null}' "zone iac-zone-office" | jq -r .id)
else echo "SKIP  zone exists" >&2; fi

# ---------- 3. Password policy (before users, so passwords meet it) ----------
# Identity Engine: send the full recovery block (as the Default Policy has it). Omitting recovery_question
# fails validation (security question authenticator disabled); a partial block returned HTTP 500 (run 1).
PWD_ID=$(find_id "/api/v1/policies?type=PASSWORD" ".[] | select(.name==\"iac-pwd-staff\")")
if [[ -z "$PWD_ID" ]]; then
  PWD_ID=$(write POST /api/v1/policies "$(jq -cn --argjson g "$ALL_GROUPS" '{
    type:"PASSWORD", name:"iac-pwd-staff", status:"ACTIVE", priority:1, description:"Lab staff password policy",
    conditions:{people:{groups:{include:$g}}, authProvider:{provider:"OKTA"}},
    settings:{password:{
      complexity:{minLength:12,minLowerCase:1,minUpperCase:1,minNumber:1,minSymbol:0,excludeUsername:true},
      age:{maxAgeDays:0,expireWarnDays:0,minAgeMinutes:0,historyCount:4},
      lockout:{maxAttempts:10,autoUnlockMinutes:0,showLockoutFailures:false}},
      recovery:{factors:{
        recovery_question:{status:"INACTIVE",properties:{complexity:{minLength:4}}},
        okta_email:{status:"ACTIVE",properties:{recoveryToken:{tokenLifetimeMinutes:60}}},
        okta_sms:{status:"INACTIVE"},okta_call:{status:"INACTIVE"}}}}}')" "policy iac-pwd-staff" | jq -r .id)
  write POST "/api/v1/policies/$PWD_ID/rules" '{"type":"PASSWORD","name":"iac-pwd-staff-rule","conditions":{"people":{"users":{"exclude":[]}},"network":{"connection":"ANYWHERE"}},"actions":{"passwordChange":{"access":"ALLOW"},"selfServicePasswordReset":{"access":"ALLOW","requirement":{"primary":{"methods":["email"]},"stepUp":{"required":false}}},"selfServiceUnlock":{"access":"DENY"}}}' "rule iac-pwd-staff-rule" >/dev/null
else echo "SKIP  password policy exists" >&2; fi

# ---------- 4. Global session policy ----------
GSP_ID=$(find_id "/api/v1/policies?type=OKTA_SIGN_ON" ".[] | select(.name==\"iac-gsp-staff\")")
if [[ -z "$GSP_ID" ]]; then
  GSP_ID=$(write POST /api/v1/policies "$(jq -cn --argjson g "$ALL_GROUPS" '{
    type:"OKTA_SIGN_ON", name:"iac-gsp-staff", status:"ACTIVE", priority:1, description:"Lab staff sessions",
    conditions:{people:{groups:{include:$g}}}}')" "policy iac-gsp-staff" | jq -r .id)
  write POST "/api/v1/policies/$GSP_ID/rules" '{"type":"SIGN_ON","name":"iac-gsp-staff-rule","conditions":{"network":{"connection":"ANYWHERE"},"authContext":{"authType":"ANY"}},"actions":{"signon":{"access":"ALLOW","requireFactor":false,"primaryFactor":"PASSWORD_IDP_ANY_FACTOR","session":{"usePersistentCookie":false,"maxSessionIdleMinutes":120,"maxSessionLifetimeMinutes":480}}}}' "rule iac-gsp-staff-rule" >/dev/null
else echo "SKIP  global session policy exists" >&2; fi

# ---------- 5. Users ----------
SEED_PW=""
need_pw() {
  [[ -n "$SEED_PW" ]] && return
  if [[ $APPLY -eq 1 ]]; then
    read -r -s -p "Shared password for the 9 seeded users (min 14 chars, upper, lower, digit): " SEED_PW; echo >&2
    [[ ${#SEED_PW} -ge 14 ]] || { echo "Too short." >&2; exit 1; }
  else SEED_PW="dry-run-not-used"; fi
}

# first|last|title|department|employeeNumber|costCenter|managerLogin|groups(csv of IT,CS,FIN)
USERS='Ada|Reyes|IT Manager|IT|1001|CC-100||IT
Ben|Okafor|Systems Engineer|IT|1002|CC-100|ada.reyes|IT
Cara|Lind|Service Desk Analyst|IT|1003|CC-100|ada.reyes|IT,CS
Dev|Patel|Customer Service Lead|CustServ|2001|CC-200||CS
Eli|Moreno|Support Agent|CustServ|2002|CC-200|dev.patel|CS
Fay|Novak|Support Agent|CustServ|2003|CC-200|dev.patel|CS
Gus|Tanaka|Finance Manager|Finance|3001|CC-300||FIN
Hana|Berg|Accountant|Finance|3002|CC-300|gus.tanaka|FIN
Ivan|Cole|Former Accountant|Finance|3003|CC-300|gus.tanaka|FIN'

while IFS='|' read -r first last title dept empno cc mgr grps; do
  handle=$(echo "$first.$last" | tr '[:upper:]' '[:lower:]')
  login="$handle@$LOGIN_DOMAIN"
  api GET "/api/v1/users/$login" >/dev/null
  if [[ "$(code)" == 200 ]]; then echo "SKIP  user $login exists" >&2; continue; fi
  need_pw
  gids="[]"
  for g in ${grps//,/ }; do
    case $g in IT) id=$GID_IT;; CS) id=$GID_CS;; FIN) id=$GID_FIN;; esac
    gids=$(echo "$gids" | jq -c --arg i "$id" '. + [$i]')
  done
  mgr_login=""; [[ -n "$mgr" ]] && mgr_login="$mgr@$LOGIN_DOMAIN"
  body=$(jq -cn --arg f "$first" --arg l "$last" --arg login "$login" \
    --arg email "$MAIL_BASE+$handle@$MAIL_DOMAIN" --arg t "$title" --arg d "$dept" \
    --arg e "$empno" --arg cc "$cc" --arg m "$mgr_login" --arg pw "$SEED_PW" --argjson g "$gids" \
    '{profile:({firstName:$f,lastName:$l,login:$login,email:$email,title:$t,department:$d,employeeNumber:$e,costCenter:$cc}
       + (if $m=="" then {} else {managerId:$m} end)),
      credentials:{password:{value:$pw}}, groupIds:$g}')
  uid=$(write POST "/api/v1/users?activate=true" "$body" "user $login" | jq -r .id)
  if [[ "$handle" == "ivan.cole" ]]; then
    write POST "/api/v1/users/$uid/lifecycle/deactivate" '' "deactivate $login" >/dev/null
  fi
done <<< "$USERS"
unset SEED_PW

# ---------- 6. Apps ----------
ensure_app() { # label json -> id
  local label=$1 body=$2 id
  id=$(find_id "/api/v1/apps?q=$label" ".[] | select(.label==\"$label\")")
  if [[ -z "$id" ]]; then
    id=$(write POST /api/v1/apps "$body" "app $label" | jq -r .id)
  else echo "SKIP  app $label exists" >&2; fi
  echo "$id"
}
assign() { write PUT "/api/v1/apps/$1/groups/$2" '{}' "assign $3" >/dev/null; }

saml_body() { # label with_attributes(0|1)
  jq -cn --arg label "$1" --arg acs "$SAML_ACS" --arg aud "$SAML_AUD" --argjson attrs "$2" '
    {label:$label, signOnMode:"SAML_2_0", visibility:{autoSubmitToolbar:false,hide:{iOS:false,web:false}},
     settings:{signOn:{
       defaultRelayState:"", ssoAcsUrl:$acs, recipient:$acs, destination:$acs, audience:$aud,
       idpIssuer:"http://www.okta.com/${org.externalKey}",
       subjectNameIdTemplate:"${user.userName}",
       subjectNameIdFormat:"urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress",
       responseSigned:true, assertionSigned:true, signatureAlgorithm:"RSA_SHA256", digestAlgorithm:"SHA256",
       honorForceAuthn:true, requestCompressed:false,
       authnContextClassRef:"urn:oasis:names:tc:SAML:2.0:ac:classes:PasswordProtectedTransport",
       attributeStatements:(if $attrs==1 then [
         {type:"EXPRESSION",name:"department",namespace:"urn:oasis:names:tc:SAML:2.0:attrname-format:unspecified",values:["user.department"]},
         {type:"EXPRESSION",name:"title",namespace:"urn:oasis:names:tc:SAML:2.0:attrname-format:unspecified",values:["user.title"]},
         {type:"EXPRESSION",name:"employeeNumber",namespace:"urn:oasis:names:tc:SAML:2.0:attrname-format:unspecified",values:["user.employeeNumber"]},
         {type:"GROUP",name:"groups",namespace:"urn:oasis:names:tc:SAML:2.0:attrname-format:unspecified",filterType:"REGEX",filterValue:".*"}
       ] else [] end)}}}'
}

APP_IT=$(ensure_app iac-saml-it-tools "$(saml_body iac-saml-it-tools 0)")
APP_CS=$(ensure_app iac-saml-custserv-desk "$(saml_body iac-saml-custserv-desk 0)")
APP_FIN=$(ensure_app iac-saml-finance-ledger "$(saml_body iac-saml-finance-ledger 0)")
APP_HR=$(ensure_app iac-saml-hr-portal "$(saml_body iac-saml-hr-portal 1)")
assign "$APP_IT" "$GID_IT" "iac-saml-it-tools -> IT"
assign "$APP_CS" "$GID_CS" "iac-saml-custserv-desk -> CustServ"
assign "$APP_FIN" "$GID_FIN" "iac-saml-finance-ledger -> Finance"
assign "$APP_HR" "$GID_IT" "iac-saml-hr-portal -> IT"
assign "$APP_HR" "$GID_CS" "iac-saml-hr-portal -> CustServ"
assign "$APP_HR" "$GID_FIN" "iac-saml-hr-portal -> Finance"

# OIDC web app. Okta generates a client secret; this script never prints or keeps it.
OIDC_BODY=$(jq -cn --arg r "$OIDC_REDIRECT" '{name:"oidc_client", label:"iac-oidc-portal", signOnMode:"OPENID_CONNECT",
  credentials:{oauthClient:{token_endpoint_auth_method:"client_secret_basic"}},
  settings:{oauthClient:{application_type:"web", redirect_uris:[$r], response_types:["code"], grant_types:["authorization_code"], consent_method:"REQUIRED"}}}')
OIDC_LOOKUP=$(api GET "/api/v1/apps?q=iac-oidc-portal" | jq -c '[.[] | select(.label=="iac-oidc-portal")][0] // empty')
if [[ -z "$OIDC_LOOKUP" ]]; then
  OIDC_LOOKUP=$(write POST /api/v1/apps "$OIDC_BODY" "app iac-oidc-portal" | jq -c '{id, credentials:{oauthClient:{client_id:.credentials.oauthClient.client_id}}}')
else echo "SKIP  app iac-oidc-portal exists" >&2; fi
APP_OIDC=$(echo "$OIDC_LOOKUP" | jq -r .id)
OIDC_CLIENT_ID=$(echo "$OIDC_LOOKUP" | jq -r .credentials.oauthClient.client_id)
assign "$APP_OIDC" "$GID_IT" "iac-oidc-portal -> IT"

# OIN app. UNVERIFIED: catalog name "slack" and settings field "domain". If this fails, add it by hand from the catalog.
APP_SLACK=$(ensure_app Slack '{"name":"slack","label":"Slack","signOnMode":"SAML_2_0","settings":{"app":{"domain":"iac-lab-placeholder"}}}')
assign "$APP_SLACK" "$GID_CS" "Slack -> CustServ"

# ---------- 7. Authentication policy ----------
AUTHN_ID=$(find_id "/api/v1/policies?type=ACCESS_POLICY" ".[] | select(.name==\"iac-authn-saml-apps\")")
if [[ -z "$AUTHN_ID" ]]; then
  AUTHN_ID=$(write POST /api/v1/policies '{"type":"ACCESS_POLICY","name":"iac-authn-saml-apps","status":"ACTIVE","description":"Lab SAML apps"}' "policy iac-authn-saml-apps" | jq -r .id)
  write POST "/api/v1/policies/$AUTHN_ID/rules" "$(jq -cn --arg g "$GID_FIN" '{
    name:"finance-2fa", type:"ACCESS_POLICY", priority:1,
    conditions:{people:{groups:{include:[$g]}}},
    actions:{appSignOn:{access:"ALLOW",verificationMethod:{type:"ASSURANCE",factorMode:"2FA",reauthenticateIn:"PT2H",constraints:[]}}}}')" "rule finance-2fa" >/dev/null
  write POST "/api/v1/policies/$AUTHN_ID/rules" "$(jq -cn --arg z "$ZONE_ID" '{
    name:"office-zone", type:"ACCESS_POLICY", priority:2,
    conditions:{network:{connection:"ZONE",include:[$z]}},
    actions:{appSignOn:{access:"ALLOW",verificationMethod:{type:"ASSURANCE",factorMode:"1FA",reauthenticateIn:"PT2H",constraints:[{knowledge:{types:["password"]}}]}}}}')" "rule office-zone" >/dev/null
else echo "SKIP  authentication policy exists" >&2; fi
# Catch-all: password only. Okta rejects the PUT (E0000077) unless it sends system:true, priority 99 and conditions:null unchanged.
if [[ $APPLY -eq 1 ]]; then
  CATCH=$(api GET "/api/v1/policies/$AUTHN_ID/rules" | jq -c '[.[] | select(.system==true)][0] // empty')
  if [[ -n "$CATCH" ]]; then
    CATCH_ID=$(echo "$CATCH" | jq -r .id)
    write PUT "/api/v1/policies/$AUTHN_ID/rules/$CATCH_ID" "$(echo "$CATCH" | jq -c '{name,type,priority,system,conditions,
      actions:{appSignOn:{access:"ALLOW",verificationMethod:{type:"ASSURANCE",factorMode:"1FA",reauthenticateIn:"PT2H",constraints:[{knowledge:{types:["password"]}}]}}}}')" "rule catch-all -> password" >/dev/null
  fi
else echo "PLAN  PUT catch-all rule -> password only" >&2; fi
for a in "$APP_IT" "$APP_CS" "$APP_FIN" "$APP_HR"; do
  write PUT "/api/v1/apps/$a/policies/$AUTHN_ID" '' "map authn policy -> $a" >/dev/null
done

# Built-in Okta Dashboard policy: its catch-all asks for 2FA, and seeded users have no second factor
# (Okta Verify enrollment is itself challenged), so sign-in fails with ENROLL. Lab: password only.
DASH_ID=$(find_id "/api/v1/policies?type=ACCESS_POLICY" ".[] | select(.name==\"Okta Dashboard\")")
if [[ $APPLY -eq 1 && -n "$DASH_ID" ]]; then
  DCATCH=$(api GET "/api/v1/policies/$DASH_ID/rules" | jq -c '[.[] | select(.system==true)][0] // empty')
  [[ -n "$DCATCH" ]] && write PUT "/api/v1/policies/$DASH_ID/rules/$(echo "$DCATCH" | jq -r .id)" "$(echo "$DCATCH" | jq -c '{name,type,priority,system,conditions,
    actions:{appSignOn:{access:"ALLOW",verificationMethod:{type:"ASSURANCE",factorMode:"1FA",reauthenticateIn:"PT12H",constraints:[{knowledge:{types:["password"]}}]}}}}')" "rule Okta Dashboard catch-all -> password" >/dev/null
else echo "PLAN  PUT Okta Dashboard catch-all rule -> password only" >&2; fi

# ---------- 8. Custom authorization server ----------
AS_ID=$(find_id "/api/v1/authorizationServers?q=iac-authz-api" ".[] | select(.name==\"iac-authz-api\")")
if [[ -z "$AS_ID" ]]; then
  AS_ID=$(write POST /api/v1/authorizationServers '{"name":"iac-authz-api","description":"Lab API","audiences":["api://iac-lab"]}' "authz server iac-authz-api" | jq -r .id)
  write POST "/api/v1/authorizationServers/$AS_ID/scopes" '{"name":"iac.read","description":"Read lab API","consent":"IMPLICIT","metadataPublish":"NO_CLIENTS"}' "scope iac.read" >/dev/null
  write POST "/api/v1/authorizationServers/$AS_ID/claims" '{"name":"department","status":"ACTIVE","claimType":"RESOURCE","valueType":"EXPRESSION","value":"user.department","alwaysIncludeInToken":true,"conditions":{"scopes":[]}}' "claim department" >/dev/null
  ASP_ID=$(write POST "/api/v1/authorizationServers/$AS_ID/policies" "$(jq -cn --arg c "$OIDC_CLIENT_ID" '{
    type:"OAUTH_AUTHORIZATION_POLICY", status:"ACTIVE", name:"iac-authz-portal", description:"Portal client", priority:1,
    conditions:{clients:{include:[$c]}}}')" "authz policy iac-authz-portal" | jq -r .id)
  write POST "/api/v1/authorizationServers/$AS_ID/policies/$ASP_ID/rules" '{"type":"RESOURCE_ACCESS","name":"allow-auth-code","priority":1,"conditions":{"people":{"groups":{"include":["EVERYONE"]}},"grantTypes":{"include":["authorization_code"]},"scopes":{"include":["*"]}},"actions":{"token":{"accessTokenLifetimeMinutes":60,"refreshTokenLifetimeMinutes":0,"refreshTokenWindowMinutes":10080}}}' "authz rule allow-auth-code" >/dev/null
else echo "SKIP  authorization server exists" >&2; fi

FAILS=$(wc -l < "$TMP/fails" | tr -d ' ')
echo "Done. Failures: $FAILS" >&2
[[ $FAILS -eq 0 ]] || { sed 's/^/  - /' "$TMP/fails" >&2; exit 1; }
