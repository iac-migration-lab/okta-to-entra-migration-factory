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

variable "name_prefix" {
  description = "Prefix for display names; selects the copy (iac = prod, iac-np = nonprod) in the one lab tenant"
  type        = string
}

variable "ca_prefix" {
  description = "CA policy name prefix, <TENANT> in <TENANT>-CA<NN> (LAB, LAB-NP)"
  type        = string
}
