# Credentials come from the Azure CLI login or ARM_* environment variables, never from this file.
provider "azuread" {
  tenant_id = var.tenant_id
}

provider "msgraph" {
  tenant_id = var.tenant_id
}
