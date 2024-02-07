variable "enable_telemetry" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see https://aka.ms/avm/telemetryinfo.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
}

# This is required for most resource modules
variable "resource_group_name" {
  description = <<DESCRIPTION
  "The name of the resource group in which to create the Azure Bastion."
  DESCRIPTION
  type        = string
}

variable "virtual_network_name" {
  description = <<DESCRIPTION
  "The name of the virtual network where Azure Bastion will be deployed."
  DESCRIPTION
  type        = string
}


variable "subnet_name" {
  description = <<DESCRIPTION
  "The name of the subnet"
  DESCRIPTION
  type        = string
  default     = "AzureBastionSubnet"

  validation {
    condition     = var.subnet_name == "AzureBastionSubnet"
    error_message = "The subnet name must be AzureBastionSubnet."
  }
}


variable "bastion_host" {
  description = <<DESCRIPTION
  "Configuration for Azure Bastion Host. The variable requires a subnet with the name AzureBastionSubnet, else the deployment will fail"
  DESCRIPTION
  type = object({
    name                = string
    resource_group_name = string
    location            = string
    copy_paste_enabled  = bool
    file_copy_enabled   = bool
    sku                 = string
    ip_configuration = object({
      name                 = string
      subnet_id            = string
      public_ip_address_id = string
    })
    ip_connect_enabled     = bool
    scale_units            = number
    shareable_link_enabled = bool
    tunneling_enabled      = bool
  })

  validation {
    condition     = basename(var.bastion_host.ip_configuration.subnet_id) == "AzureBastionSubnet"
    error_message = "The subnet name must be AzureBastionSubnet."

  }
  default = {
    name                = "example-bastion"
    resource_group_name = "example-resources"
    location            = "West Europe"
    copy_paste_enabled  = true
    file_copy_enabled   = false // Remember that this is only applicable for Standard SKU
    sku                 = "Standard"
    ip_configuration = {
      name                 = "example-ipconfig"
      subnet_id            = "subnet-id"
      public_ip_address_id = "public-ip-id"
    }
    ip_connect_enabled     = false // Only applicable for Standard SKU
    scale_units            = 2     // Only changeable for Standard SKU and always 2 for Basic
    shareable_link_enabled = false // Only applicable for Standard SKU
    tunneling_enabled      = false // Only applicable for Standard SKU
    tags                   = {}
  }


}

## AVM Required Interfaces
//Diagnostic Settings
variable "diagnostic_settings" {
  type = map(object({
    name                                     = optional(string, null)
    log_categories                           = optional(set(string), [])
    log_groups                               = optional(set(string), ["allLogs"])
    metric_categories                        = optional(set(string), ["AllMetrics"])
    log_analytics_destination_type           = optional(string, "Dedicated")
    workspace_resource_id                    = optional(string, null)
    storage_account_resource_id              = optional(string, null)
    event_hub_authorization_rule_resource_id = optional(string, null)
    event_hub_name                           = optional(string, null)
    marketplace_partner_resource_id          = optional(string, null)
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for _, v in var.diagnostic_settings : contains(["Dedicated", "AzureDiagnostics"], v.log_analytics_destination_type)])
    error_message = "Log analytics destination type must be one of: 'Dedicated', 'AzureDiagnostics'."
  }
  validation {
    condition = alltrue(
      [
        for _, v in var.diagnostic_settings :
        v.workspace_resource_id != null || v.storage_account_resource_id != null || v.event_hub_authorization_rule_resource_id != null || v.marketplace_partner_resource_id != null
      ]
    )
    error_message = "At least one of `workspace_resource_id`, `storage_account_resource_id`, `marketplace_partner_resource_id`, or `event_hub_authorization_rule_resource_id`, must be set."
  }
  description = <<DESCRIPTION
  A map of diagnostic settings to create on the Key Vault. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.
  
  - `name` - (Optional) The name of the diagnostic setting. One will be generated if not set, however this will not be unique if you want to create multiple diagnostic setting resources.
  - `log_categories` - (Optional) A set of log categories to send to the log analytics workspace. Defaults to `[]`.
  - `log_groups` - (Optional) A set of log groups to send to the log analytics workspace. Defaults to `["allLogs"]`.
  - `metric_categories` - (Optional) A set of metric categories to send to the log analytics workspace. Defaults to `["AllMetrics"]`.
  - `log_analytics_destination_type` - (Optional) The destination type for the diagnostic setting. Possible values are `Dedicated` and `AzureDiagnostics`. Defaults to `Dedicated`.
  - `workspace_resource_id` - (Optional) The resource ID of the log analytics workspace to send logs and metrics to.
  - `storage_account_resource_id` - (Optional) The resource ID of the storage account to send logs and metrics to.
  - `event_hub_authorization_rule_resource_id` - (Optional) The resource ID of the event hub authorization rule to send logs and metrics to.
  - `event_hub_name` - (Optional) The name of the event hub. If none is specified, the default event hub will be selected.
  - `marketplace_partner_resource_id` - (Optional) The full ARM resource ID of the Marketplace resource to which you would like to send Diagnostic LogsLogs.
  DESCRIPTION
}


//RBAC Assignment
variable "role_assignments" {
  type = map(object({
    role_definition_id_or_name             = string
    principal_id                           = string
    description                            = optional(string, null)
    skip_service_principal_aad_check       = optional(bool, false)
    condition                              = optional(string, null)
    condition_version                      = optional(string, null)
    delegated_managed_identity_resource_id = optional(string, null)
  }))
  default     = {}
  description = <<DESCRIPTION
  A map of role assignments to create on the Key Vault. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.
  
  - `role_definition_id_or_name` - The ID or name of the role definition to assign to the principal.
  - `principal_id` - The ID of the principal to assign the role to.
  - `description` - The description of the role assignment.
  - `skip_service_principal_aad_check` - If set to true, skips the Azure Active Directory check for the service principal in the tenant. Defaults to false.
  - `condition` - The condition which will be used to scope the role assignment.
  - `condition_version` - The version of the condition syntax. Leave as `null` if you are not using a condition, if you are then valid values are '2.0'.
  
  > Note: only set `skip_service_principal_aad_check` to true if you are assigning a role to a service principal.
  DESCRIPTION
}


//Resource Locks

variable "lock" {
  type = object({
    name = optional(string, null)
    kind = optional(string, "None")
  })
  description = "The lock level to apply to the Key Vault. Possible values are `None`, `CanNotDelete`, and `ReadOnly`."
  default     = {}
  nullable    = false
  validation {
    condition     = contains(["CanNotDelete", "ReadOnly", "None"], var.lock.kind)
    error_message = "The lock level must be one of: 'None', 'CanNotDelete', or 'ReadOnly'."
  }
}


//Tags

variable "tags" {
  type        = map(any)
  default     = {}
  description = <<DESCRIPTION
  A mapping of tags to assign to the resource.
  DESCRIPTION
}
