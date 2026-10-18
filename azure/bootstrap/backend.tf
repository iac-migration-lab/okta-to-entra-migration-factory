terraform {
  backend "azurerm" {
    storage_account_name = "stiaclabtfstate02"
    container_name       = "tfstate-prod"
    key                  = "azure/bootstrap/terraform.tfstate"
    use_azuread_auth     = true
  }
}
