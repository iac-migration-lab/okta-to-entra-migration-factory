terraform {
  required_version = "= 1.16.4"

  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "= 3.10.0" # ~> 3.9 per the Session 4 prompt; exact pin because .terraform.lock.hcl is git-ignored
    }
  }
}
