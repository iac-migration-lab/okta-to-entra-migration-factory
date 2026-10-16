terraform {
  required_version = "= 1.16.4"

  required_providers {
    okta = {
      source  = "okta/okta"
      version = "= 7.0.0" # ~> 7.0 per build-phases; exact pin because .terraform.lock.hcl is git-ignored
    }
  }
}
