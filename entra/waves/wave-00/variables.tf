variable "tenant_key" {
  description = "Short name of the target tenant; selects tenants/<tenant_key>.tfvars"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.tenant_key))
    error_message = "tenant_key: lower case letters, digits, dashes."
  }
}

variable "tenant_id" {
  description = "Entra tenant ID"
  type        = string
}
