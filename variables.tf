variable "location" {
  type        = string
  description = "The location of the Azure Bastion Host."
  nullable    = false
}

variable "name" {
  type        = string
  description = "The name of the Azure Bastion Host."
}

variable "resource_group_name" {
  type        = string
  description = "The name of the resource group where the Azure Bastion Host is located."
}

variable "copy_paste_enabled" {
  type        = bool
  default     = true
  description = "Specifies whether copy-paste functionality is enabled for the Azure Bastion Host."
  nullable    = false
}

variable "file_copy_enabled" {
  type        = bool
  default     = false
  description = "Specifies whether file copy functionality is enabled for the Azure Bastion Host."
  nullable    = false
}

variable "ip_configuration" {
  type = object({
    name                 = string
    subnet_id            = string
    public_ip_address_id = string
  })
  default     = null
  description = <<DESCRIPTION
The IP configuration for the Azure Bastion Host.

- `name` - The name of the IP configuration.
- `subnet_id` - The ID of the subnet where the Azure Bastion Host will be deployed.
- `public_ip_address_id` - The ID of the public IP address associated with the Azure Bastion Host.
DESCRIPTION
}

variable "ip_connect_enabled" {
  type        = bool
  default     = false
  description = "Specifies whether IP connect functionality is enabled for the Azure Bastion Host."
  nullable    = false
}

variable "kerberos_enabled" {
  type        = bool
  default     = false
  description = "Specifies whether Kerberos authentication is enabled for the Azure Bastion Host."
  nullable    = false
}

variable "scale_units" {
  type        = number
  default     = 2
  description = "The number of scale units for the Azure Bastion Host."
  nullable    = false
}

variable "session_recording_enabled" {
  type        = bool
  default     = false
  description = "Specifies whether session recording functionality is enabled for the Azure Bastion Host."
  nullable    = false
}

variable "shareable_link_enabled" {
  type        = bool
  default     = false
  description = "Specifies whether shareable link functionality is enabled for the Azure Bastion Host."
  nullable    = false
}

variable "sku" {
  type        = string
  default     = "Basic"
  description = <<DESCRIPTION
The SKU of the Azure Bastion Host.
Valid values are 'Basic', 'Standard', and 'Developer'.
DESCRIPTION
  nullable    = false

  validation {
    condition     = can(regex("^(Basic|Standard|Developer)$", var.sku))
    error_message = "The SKU must be either 'Basic', 'Standard', or 'Developer'."
  }
}

variable "tunneling_enabled" {
  type        = bool
  default     = false
  description = "Specifies whether tunneling functionality is enabled for the Azure Bastion Host."
  nullable    = false
}

variable "virtual_network_id" {
  type        = string
  default     = null
  description = "The ID of the virtual network where the Azure Bastion Host is deployed."
}
