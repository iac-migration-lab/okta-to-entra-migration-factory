# State in Azure Storage, Entra ID auth (shared-key access is off on the account).
# Run 1 locally: iac-reader with the local certificate (ARM_CLIENT_ID, ARM_TENANT_ID,
# ARM_CLIENT_CERTIFICATE_PATH); see README. In GitHub Actions: OIDC federation.
terraform {
  backend "azurerm" {
    storage_account_name = "stiaclabtfstate02"
    container_name       = "tfstate-prod"
    key                  = "entra/legacy/terraform.tfstate"
    use_azuread_auth     = true
  }
}
