variable "resource_group_name" {
  type        = string
  default     = "rg-bookreview-prod-centralindia"
  description = "Resource Group Name"
}

variable "location" {
  type        = string
  default     = "Central India" # "South India" or "Central India" depending on regional B-series availability
  description = "Azure Region for deployment"
}

variable "vm_size" {
  type        = string
  default     = "Standard_B2ats_v2"
  description = "VM size specified in requirements"
}

variable "admin_username" {
  type        = string
  default     = "azureadmin"
  description = "Admin username for Virtual Machines"
}

variable "admin_password" {
  type        = string
  sensitive   = true
  description = "Admin password for VMs and DB (must meet Azure complexity requirements)"
}

variable "environment" {
  type        = string
  default     = "production"
  description = "Environment tag"
}