terraform {
  required_version = "= 1.16.4"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "= 4.81.0" # exact pin; .terraform.lock.hcl is git-ignored
    }
  }
}
