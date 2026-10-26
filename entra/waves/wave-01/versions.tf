terraform {
  required_version = "= 1.16.4"

  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "= 3.10.0"
    }
    msgraph = {
      source  = "microsoft/msgraph"
      version = "= 0.5.0" # preview provider; active SAML signing keys and the it-tools customClaimsPolicy
    }
  }
}
