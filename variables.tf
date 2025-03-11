# The private only option for this module will be available in a future release.
# variable "private_only" {
#   type        = bool
#   default     = false
#   description = "Specifies whether the Azure Bastion Host is configured to be private only."
#   nullable    = false

#   validation {
#     condition     = (var.private_only == true && var.sku == "Premium") || var.private_only == false
#     error_message = "Private only functionality is only available for Premium SKU."
#   }
# }

variable "location" {
  type        = string
  description = "The location of the Azure Bastion Host and related resources."
  nullable    = false
}

variable "name" {
  type        = string
  description = "The name of the Azure Bastion Host."
}

variable "resource_group_name" {
  type        = string
  description = "The name of the resource group where the Azure Bastion Host will be deployed."
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
    name                 = optional(string)
    subnet_id            = string
    create_public_ip     = optional(bool, true)
    public_ip_address_id = optional(string, null)
  })
  default     = null
  description = <<DESCRIPTION
The IP configuration for the Azure Bastion Host.
- `name` - The name of the IP configuration.
- `subnet_id` - The ID of the subnet where the Azure Bastion Host will be deployed.
- `create_public_ip` - Specifies whether a public IP address should be created by the module. if both `create_public_ip` and `public_ip_address_id` are set, the `public_ip_address_id` will be ignored.
- `public_ip_address_id` - The ID of the public IP address associated with the Azure Bastion Host.
DESCRIPTION

  validation {
    condition     = (var.sku == "Developer" && var.ip_configuration == null) || (var.sku != "Developer" && var.ip_configuration != null)
    error_message = "The IP configuration is not required for the Developer SKU."
  }
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
  description = "The ID of the virtual the Developer SKU Bastion hosts is attached to. Required for the Developer SKU Only."

  validation {
    condition     = (var.sku == "Developer" && var.virtual_network_id != null) || var.sku != "Developer" && var.virtual_network_id == null
    error_message = "The virtual network ID is required for the Developer SKU (Only)."
  }
}

variable "zones" {
  type        = list(number)
  default     = [1, 2, 3]
  description = "The availability zones where the Azure Bastion Host is deployed."

  validation {
    condition     = (length(var.zones) >= 0 && var.sku != "Developer") || length(var.zones) == 0 && var.sku == "Developer"
    error_message = "The Developer SKU does not support availability zones."
  }
}
