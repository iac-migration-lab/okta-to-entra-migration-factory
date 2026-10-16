# State in Azure Storage, Entra ID auth (shared-key access is off on the account).
# Run 1 locally: the owner's Azure CLI login (Global Administrator, delegated). In GitHub Actions: OIDC federation.
terraform {
  backend "azurerm" {
    storage_account_name = "stiaclabtfstate02"
    container_name       = "tfstate-prod"
    key                  = "entra/waves/wave-00/terraform.tfstate"
    use_azuread_auth     = true
  }
}
