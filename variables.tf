variable "ip_configuration" {
  type = object({
    name                 = optional(string)
    subnet_id            = string
    public_ip_address_id = optional(string, null)
  })
  description = <<DESCRIPTION
The IP configuration for the Azure Bastion Host.
- `name` - The name of the IP configuration.
- `subnet_id` - The ID of the subnet where the Azure Bastion Host will be deployed.
- `public_ip_address_id` - The ID of the public IP address associated with the Azure Bastion Host.
DESCRIPTION
}

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

variable "private_only" {
  type        = bool
  default     = false
  description = "Specifies whether the Azure Bastion Host is configured to be private only."
  nullable    = false

  validation {
    condition     = (var.private_only == true && var.sku == "Premium") || var.private_only == false
    error_message = "Private only functionality is only available for Premium SKU."
  }
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

  validation {
    condition     = var.session_recording_enabled == true ? var.sku == "Premium" : true
    error_message = "Session recording functionality is only availble for Premium SKU."
  }
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
Valid values are 'Basic', 'Standard', 'Developer' or 'Premium'.
DESCRIPTION
  nullable    = false

  validation {
    condition     = can(regex("^(Basic|Standard|Developer|Premium)$", var.sku))
    error_message = "The SKU must be either 'Basic', 'Standard', 'Developer', or 'Premium'."
  }
}

variable "tunneling_enabled" {
  type        = bool
  default     = false
  description = "Specifies whether tunneling functionality is enabled for the Azure Bastion Host."
  nullable    = false

  validation {
    condition     = var.session_recording_enabled == true && var.tunneling_enabled == true ? false : true
    error_message = "Tunneling functionality is not compatible with session recording functionality."
  }
}

variable "virtual_network_id" {
  type        = string
  default     = null
  description = "The ID of the virtual network where the Azure Bastion Host is deployed."
}

variable "zones" {
  type        = list(number)
  default     = [1, 2, 3]
  description = "The availability zones where the Azure Bastion Host is deployed."

  validation {
    condition     = (length(var.zones) > 1 && var.sku == "Developer") || length(var.zones) >= 0 && var.sku != "Developer"
    error_message = "The Developer SKU does not support availability zones."
  }
}
