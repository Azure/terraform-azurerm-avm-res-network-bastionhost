variable "location" {
  type        = string
  description = "The location of the Azure Bastion Host and related resources."
  nullable    = false
}

variable "name" {
  type        = string
  description = "The name of the Azure Bastion Host."
}

variable "parent_id" {
  type        = string
  description = "The ID of the resource group where the Azure Bastion Host will be deployed."

  validation {
    # TFNFR38 (Severity-MUST): validate the resource ID through a LITERAL type passed to
    # `parse_resource_id`, never a hand-rolled regex. The literal keeps the ID pinned to
    # resource-group scope, which this module depends on in three places: it is forwarded
    # verbatim as `parent_id` to `module.public_ip_address`, whose own TFNFR38 validation
    # would reject anything else; `local.parent_resource_group.subscription_id` feeds
    # `local.role_assignment_definition_scope` and so the role-definition lookup; and
    # `azapi_resource.bastion.parent_id` must be the Bastion host's real ARM parent.
    #
    # Measured at azapi 2.13.0: `parse_resource_id("Microsoft.Resources/resourceGroups", x)`
    # succeeds for "/subscriptions/<sub>/resourceGroups/<rg>" and FAILS for a bare
    # "/subscriptions/<sub>", so the literal alone is enough and no extra non-empty check
    # is needed the way it is for deeper types.
    condition     = can(provider::azapi::parse_resource_id("Microsoft.Resources/resourceGroups", var.parent_id))
    error_message = "`parent_id` must be a resource group resource ID, for example \"/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-example\"."
  }
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

variable "ignore_body_changes" {
  type = object({
    authorization_locks            = optional(list(string), [])
    authorization_role_assignments = optional(list(string), [])
    insights_diagnostic_settings   = optional(list(string), [])
    network_bastion_hosts          = optional(list(string), [])
  })
  default     = {}
  description = <<DESCRIPTION
(Optional) Body property paths whose changes the `azapi` provider ignores after creation, letting an out-of-band controller own those properties without producing perpetual `terraform plan` drift.

- `authorization_locks` - (Optional) Ignored body paths for the management locks on the Bastion host and its module-created public IP, for example `["properties.notes"]`. Default `[]`.
- `authorization_role_assignments` - (Optional) Ignored body paths for the role assignments, for example `["properties.description"]`. Default `[]`.
- `insights_diagnostic_settings` - (Optional) Ignored body paths for the Bastion host diagnostic settings, for example `["properties.logs"]`. Default `[]`.
- `network_bastion_hosts` - (Optional) Ignored body paths for the Bastion host itself, for example `["properties.scaleUnits"]`. Default `[]`. Applies to BOTH Bastion writers -- the Developer SKU is a separate `azapi_resource` of the same ARM type and only one of the two exists for any given `sku`.

Paths are body-relative dot notation and cannot target list indices. While a path is ignored, configuration changes at that path are no longer sent to Azure. The value is write-only provider state, so a change only takes effect after an `apply`, and supplying a non-empty list requires Terraform 1.11 or later.

> Note: empty lists are collapsed to `null` before reaching the resource, because `azapi_resource` treats `[]` and `null` differently and only `null` means "ignore nothing".
DESCRIPTION
  nullable    = false

  validation {
    condition     = alltrue([for path in var.ignore_body_changes.authorization_locks : length(trimspace(path)) > 0])
    error_message = "Every ignore_body_changes.authorization_locks entry must be a non-empty body path in dot notation, for example \"properties.notes\"."
  }
  validation {
    condition     = alltrue([for path in var.ignore_body_changes.authorization_role_assignments : length(trimspace(path)) > 0])
    error_message = "Every ignore_body_changes.authorization_role_assignments entry must be a non-empty body path in dot notation, for example \"properties.description\"."
  }
  validation {
    condition     = alltrue([for path in var.ignore_body_changes.insights_diagnostic_settings : length(trimspace(path)) > 0])
    error_message = "Every ignore_body_changes.insights_diagnostic_settings entry must be a non-empty body path in dot notation, for example \"properties.logs\"."
  }
  validation {
    condition     = alltrue([for path in var.ignore_body_changes.network_bastion_hosts : length(trimspace(path)) > 0])
    error_message = "Every ignore_body_changes.network_bastion_hosts entry must be a non-empty body path in dot notation, for example \"properties.scaleUnits\"."
  }
}

variable "ip_configuration" {
  type = object({
    name                             = optional(string)
    subnet_id                        = string
    create_public_ip                 = optional(bool, true)
    public_ip_tags                   = optional(map(string), null)
    public_ip_merge_with_module_tags = optional(bool, true)
    public_ip_address_name           = optional(string, null)
    public_ip_address_id             = optional(string, null)
  })
  default     = null
  description = <<DESCRIPTION
The IP configuration for the Azure Bastion Host.
- `name` - The name of the IP configuration.
- `subnet_id` - The ID of the subnet where the Azure Bastion Host will be deployed.
- `create_public_ip` - Specifies whether a public IP address should be created by the module. 
- `public_ip_tags` - A map of tags to apply to the public IP address.
- `public_ip_merge_with_module_tags` - If set to true, the public IP tags will be merged with the module's tags. If set to false, only the `public_ip_tags` will be applied to the public IP address.
- `public_ip_address_name` - The Name of the public IP address to create. Will be ignored if `public_ip_address_id` is set.
- `public_ip_address_id` - The ID of the public IP address associated with the Azure Bastion Host. If Set, create_public_ip must be set to false.
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
  validation {
    condition     = var.ip_configuration == null ? true : var.ip_configuration.create_public_ip && var.ip_configuration.public_ip_address_id != null ? false : true
    error_message = <<ERROR
*** Variable Validation Error ***
Both create_public_ip and public_ip_address_id cannot be supplied at the same time.
If you want the module to create a public IP address, set create_public_ip to true and remove the public_ip_address_id.
If you want to use an existing public IP address, set create_public_ip to false and provide the public_ip_address_id.
ERROR
  }
  validation {
    # TFNFR38, for the two resource IDs this object carries.
    #
    # AzureRM parity, not a new restriction. `subnet_id` was
    # `ValidateFunc: commonids.ValidateSubnetID` (`bastion_host_resource.go`, the
    # `ip_configuration` block) and `public_ip_address_id` was
    # `ValidateFunc: commonids.ValidatePublicIPAddressID`, both at v4.81.0, so a malformed
    # ID failed at plan and never reached ARM. AzAPI has no such guard, and an unvalidated
    # `public_ip_address_id` additionally reaches `data.azapi_resource.public_ip` in
    # `main.tf`, where a bad value would surface as an opaque 404 during refresh.
    condition = var.ip_configuration == null ? true : (
      can(provider::azapi::parse_resource_id("Microsoft.Network/virtualNetworks/subnets", var.ip_configuration.subnet_id)) &&
      (
        var.ip_configuration.public_ip_address_id == null ||
        can(provider::azapi::parse_resource_id("Microsoft.Network/publicIPAddresses", var.ip_configuration.public_ip_address_id))
      )
    )
    error_message = "`ip_configuration.subnet_id` must be a `Microsoft.Network/virtualNetworks/subnets` resource ID and `ip_configuration.public_ip_address_id`, when set, must be a `Microsoft.Network/publicIPAddresses` resource ID."
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
  description = "Specifies whether the Azure Bastion Host is configured to be private only. This is a premium SKU feature."
  nullable    = false

  validation {
    condition     = var.private_only_enabled == true ? var.sku == "Premium" : true
    error_message = "Private only functionality is only available for Premium SKU."
  }
}

variable "resource_types" {
  type = object({
    authorization_locks            = optional(string, "Microsoft.Authorization/locks@2020-05-01")
    authorization_role_assignments = optional(string, "Microsoft.Authorization/roleAssignments@2022-04-01")
    insights_diagnostic_settings   = optional(string, "Microsoft.Insights/diagnosticSettings@2021-05-01-preview")
    network_bastion_hosts          = optional(string, "Microsoft.Network/bastionHosts@2024-05-01")
    network_public_ip_addresses    = optional(string, "Microsoft.Network/publicIPAddresses@2024-05-01")
  })
  default     = {}
  description = <<DESCRIPTION
(Optional) The Azure resource type and API version used for each resource this module reads or writes.

- `authorization_locks` - (Optional) The type and API version of the management locks. Default `Microsoft.Authorization/locks@2020-05-01`, which is the value `Azure/avm-utl-interfaces/azure` 0.6.0 emits from `lock_azapi.type`.
- `authorization_role_assignments` - (Optional) The type and API version of the role assignments. Default `Microsoft.Authorization/roleAssignments@2022-04-01`, which is the value `Azure/avm-utl-interfaces/azure` 0.6.0 emits.
- `insights_diagnostic_settings` - (Optional) The type and API version of the diagnostic settings. Default `Microsoft.Insights/diagnosticSettings@2021-05-01-preview`, which is both the value `Azure/avm-utl-interfaces/azure` 0.6.0 emits and the version `hashicorp/azurerm` v4.81.0 used.
- `network_bastion_hosts` - (Optional) The type and API version of the Bastion host. Default `Microsoft.Network/bastionHosts@2024-05-01`, carried forward unchanged from this module's v0.9.0 so that an upgrade is not silently also an API-version bump. Applies to BOTH Bastion writers.
- `network_public_ip_addresses` - (Optional) The type and API version used to READ an existing public IP supplied through `ip_configuration.public_ip_address_id`. Nothing is written at this type; the module-created public IP is owned by `Azure/avm-res-network-publicipaddress/azurerm`.

> 🔴 Changing any WRITE key on an EXISTING deployment is a breaking change, not a routine bump. `type` is not a replacement trigger on `azapi_resource` (azapi 2.13.0 `azapi_resource.go` declares no `RequiresReplace` on it) and it carries no `skip_on:"update"` tag either, so a changed value forces a full PUT rather than replacing the resource. Plan it, read it, and do not apply it casually.
>
> 🔴 The interface types are configurable to satisfy the AVM target checklist, but the BODIES sent at those types come from `Azure/avm-utl-interfaces/azure` 0.6.0 and are shaped for the default API versions. Overriding a type without checking that the body still validates against the new version is on the consumer.
DESCRIPTION
  nullable    = false
}

variable "retry" {
  type = object({
    error_message_regex  = optional(list(string), ["ReferencedResourceNotProvisioned"])
    interval_seconds     = optional(number, 10)
    max_interval_seconds = optional(number, 180)
  })
  default     = {}
  description = "(Optional) Retry configuration for the resource operations."
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

variable "timeouts" {
  type = object({
    create = optional(string)
    read   = optional(string)
    update = optional(string)
    delete = optional(string)
  })
  default     = {}
  description = <<DESCRIPTION
(Optional) Timeouts for the resource operations. Each value is a Go duration string, for example `30m` or `1h`.

- `create` - (Optional) Timeout for create operations.
- `read`   - (Optional) Timeout for read operations.
- `update` - (Optional) Timeout for update operations.
- `delete` - (Optional) Timeout for delete operations.

The shape is the flat TFFR7 one, so a parent module can cascade `timeouts = var.timeouts` through unchanged.

An attribute left unset does NOT fall back to a single blanket value. It falls back PER RESOURCE to the timeout default of the `hashicorp/azurerm` v4.81.0 resource that resource replaced, so a migrated deployment keeps the timeouts it had. The fallbacks and their sources are in `local.timeouts` in `locals.tf`:

- The Bastion host - create `30m`, read `5m`, update `30m`, delete `30m` (`network/bastion_host_resource.go`).
- The management locks - create `30m`, read `5m`, update `30m`, delete `30m` (`resource/management_lock_resource.go`; it declares no Update timeout at all because every attribute is ForceNew, so the create value is reused).
- The role assignments - create `30m`, read `5m`, update `30m`, delete `30m` (`authorization/role_assignment_resource.go`; same, no Update timeout declared).
- The diagnostic settings - create `30m`, read `5m`, update `30m`, delete `60m` (`monitor/monitor_diagnostic_setting_resource.go`). Note the `60m` delete, which is NOT the Bastion host's `30m`. That asymmetry is the reason the fallbacks are per resource rather than one shared object.

Passing `null` is equivalent to passing `{}`: every fallback applies. `nullable = false` is deliberately NOT set here -- TFFR7 requires this variable to accept `null`, and `avm_interface_timeouts` fails the build if it is set. `local.timeouts_input` in `locals.tf` absorbs the null so the fallback table below it never has to.
DESCRIPTION
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
  validation {
    # TFNFR38. AzureRM parity: `virtual_network_id` carried
    # `ValidateFunc: commonids.ValidateVirtualNetworkID` at v4.81.0.
    condition     = var.virtual_network_id == null ? true : can(provider::azapi::parse_resource_id("Microsoft.Network/virtualNetworks", var.virtual_network_id))
    error_message = "`virtual_network_id`, when set, must be a `Microsoft.Network/virtualNetworks` resource ID."
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
