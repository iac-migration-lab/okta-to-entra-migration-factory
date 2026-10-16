# Credentials come from ARM_* environment variables, never from this file.
provider "azuread" {
  tenant_id = var.tenant_id
}
