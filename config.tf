variable "terraform_resource_group" {
  type        = "string"
  description = "Azure resource group"
  default     = "East US"
}

variable "terraform_azure_region" {
  type        = "string"
  description = "Azure region for deployment"
  default     = "East US"
}

variable "terraform_vmss_count" {
  description = "VMSS count"
  default     = 3
}

