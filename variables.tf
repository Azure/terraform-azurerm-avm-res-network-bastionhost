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

  validation {
    condition     = var.copy_paste_enabled == false ? can(regex("^(Standard|Premium)$", var.sku)) : true
    error_message = "Copy-paste functionality is only available for the Standard and the Premium SKU."
  }
}

variable "file_copy_enabled" {
  type        = bool
  default     = false
  description = "Specifies whether file copy functionality is enabled for the Azure Bastion Host."
  nullable    = false

  validation {
    condition     = var.file_copy_enabled == true ? can(regex("^(Standard|Premium)$", var.sku)) : true
    error_message = "File copy functionality is only available for the Standard and the Premium SKU."
  }
}

variable "ip_configuration" {
  type = object({
    name                   = optional(string)
    subnet_id              = string
    create_public_ip       = optional(bool, true)
    public_ip_address_name = optional(string, null)
    public_ip_address_id   = optional(string, null)
  })
  default     = null
  description = <<DESCRIPTION
The IP configuration for the Azure Bastion Host.
- `name` - The name of the IP configuration.
- `subnet_id` - The ID of the subnet where the Azure Bastion Host will be deployed.
- `create_public_ip` - Specifies whether a public IP address should be created by the module. if both `create_public_ip` and `public_ip_address_id` are set, the `public_ip_address_id` will be ignored.
- `public_ip_address_name` - The Name of the public IP address to create. Will be ignored if `public_ip_address_id` is set.
- `public_ip_address_id` - The ID of the public IP address associated with the Azure Bastion Host.
DESCRIPTION

  validation {
    condition     = (var.sku == "Developer" && var.ip_configuration == null) || (var.sku != "Developer" && var.ip_configuration != null)
    error_message = <<ERROR
The IP configuration is required for all skus other than the Developer SKU.
If you are trying to deploy the Developer SKU, please remove the ip_configuration block.
If you are trying to deploy basic, standard or premium SKU, make sure to provide the ip_configuration block.
ERROR
  }
  validation {
    condition     = var.private_only_enabled == true ? (var.ip_configuration != null && (var.ip_configuration.create_public_ip == false && var.ip_configuration.public_ip_address_id == null)) : true
    error_message = "Public IP must not be provided when private only is enabled."
  }
  validation {
    condition     = var.ip_configuration != null ? (var.private_only_enabled == false && var.ip_configuration.create_public_ip == false ? var.ip_configuration.public_ip_address_id != null : true) : true
    error_message = "Public IP address ID must be provided when create_public_ip is set to false."
  }
}

variable "ip_connect_enabled" {
  type        = bool
  default     = false
  description = "Specifies whether IP connect functionality is enabled for the Azure Bastion Host."
  nullable    = false

  validation {
    condition     = var.ip_connect_enabled == true ? can(regex("^(Standard|Premium)$", var.sku)) : true
    error_message = "IP connect functionality is only available for the Standard and the Premium SKU."
  }
}

variable "kerberos_enabled" {
  type        = bool
  default     = false
  description = "Specifies whether Kerberos authentication is enabled for the Azure Bastion Host."
  nullable    = false

  validation {
    condition     = var.kerberos_enabled == true ? var.sku != "Developer" : true
    error_message = "Kerberos authentication is not available for the Developer SKU."
  }
}

variable "private_only_enabled" {
  type        = bool
  default     = false
  description = "Specifies whether the Azure Bastion Host is configured to be private only."
  nullable    = false

  validation {
    condition     = var.private_only_enabled == true ? var.sku == "Premium" : true
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

  validation {
    condition     = var.shareable_link_enabled == true ? can(regex("^(Standard|Premium)$", var.sku)) : true
    error_message = "Shareable link functionality is only available for the Standard and the Premium SKU."
  }
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
  description = "Specifies whether tunneling functionality is enabled for the Azure Bastion Host. (Native client support for SSH and RDP tunneling)"
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
    error_message = "The virtual_network_id is required for the Developer SKU (Only). If you are trying to deploy the Developer SKU, please provide the virtual_network_id. if not, please remove it."
  }
}

variable "zones" {
  type        = set(string)
  default     = ["1", "2", "3"]
  description = "The availability zones where the Azure Bastion Host is deployed."

  validation {
    condition     = (length(var.zones) >= 0 && var.sku != "Developer") || length(var.zones) == 0 && var.sku == "Developer"
    error_message = "The Developer SKU does not support availability zones. Please set the zones to an empty list. zones = [  ]"
  }
}
