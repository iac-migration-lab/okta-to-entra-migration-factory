# Read-only inventory of the lab Okta org. Auth: OAuth 2.0 service app iac-okta-reader, private key JWT.
# Never applied. The private key is never in a file in this repo:
#   OKTA_API_PRIVATE_KEY      path to ~/.okta-lab/iac-okta-reader.pem locally; key contents from a secret in CI
#   OKTA_API_PRIVATE_KEY_ID   key ID (kid)
provider "okta" {
  org_name         = "integrator-2631921"
  base_url         = "okta.com"
  client_id        = "0oa18siafpuScaofm698"
  scopes           = ["okta.apps.read", "okta.users.read", "okta.groups.read", "okta.policies.read", "okta.authorizationServers.read", "okta.idps.read", "okta.schemas.read", "okta.networkZones.read"]
  max_api_capacity = 50
}
