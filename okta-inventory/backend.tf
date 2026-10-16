# State in Azure Storage, Entra ID auth (shared-key access is off on the account).
# Locally: Azure CLI login. In GitHub Actions: OIDC federation (ARM_USE_OIDC, ARM_CLIENT_ID, ARM_TENANT_ID).
terraform {
  backend "azurerm" {
    storage_account_name = "stiaclabtfstate02"
    container_name       = "tfstate-prod"
    key                  = "okta-inventory/terraform.tfstate"
    use_azuread_auth     = true
  }
}
