# Bootstrap root: Azure objects the pipeline itself depends on. Applied locally by the owner (Azure CLI login),
# never by the pipeline: the pipeline identities hold no subscription roles, and this root would manage
# the storage that holds pipeline state.
provider "azurerm" {
  features {}
  subscription_id                 = "6ea51c80-90de-4914-bbc6-2af9b54bba9f"
  resource_provider_registrations = "none"
}
