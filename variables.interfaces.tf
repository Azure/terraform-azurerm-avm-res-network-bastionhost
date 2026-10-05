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
  default     = {}
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

Example usage:
```hcl

diagnostic_settings = {
  setting1 = {
    log_analytics_destination_type = "Dedicated"
    workspace_resource_id = "logAnalyticsWorkspaceResourceId"
  }
}
```

> ⚠️ `log_analytics_destination_type` IS SENT AGAIN AS OF THIS RELEASE. v0.6.0 passed it to `azurerm_monitor_diagnostic_setting`; v0.7.0 dropped the argument while keeping the variable, so between v0.7.0 and v0.9.0 the documented default `Dedicated` was silently discarded and ARM applied its own default. Composing the interface through `Azure/avm-utl-interfaces/azure` restores the v0.6.0 behaviour. A deployment created on v0.7.0-v0.9.0 with a Log Analytics destination will therefore show ONE in-place update to `properties.logAnalyticsDestinationType` on first plan after upgrading. That is a bug fix, not a regression, and it is an update rather than a replacement.
DESCRIPTION
  nullable    = false

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
  validation {
    # AzureRM parity, ADDED by the AzAPI migration.
    # `monitor_diagnostic_setting_resource.go` (v4.81.0) hard-failed with "at least one
    # type of Log or Metric must be enabled" before ever calling ARM, and the comment
    # above that check explains why: with neither, the API "creates" the setting but then
    # 404s on Read. AzAPI has no such guard, so a config AzureRM rejected at plan would now
    # create an unreadable object.
    #
    # No previously-working configuration can trip this: `log_groups` defaults to
    # `["allLogs"]` and `metric_categories` to `["AllMetrics"]`, so reaching the failure
    # requires explicitly emptying all three.
    condition = alltrue(
      [
        for _, v in var.diagnostic_settings :
        length(coalesce(v.log_categories, [])) > 0 || length(coalesce(v.log_groups, [])) > 0 || length(coalesce(v.metric_categories, [])) > 0
      ]
    )
    error_message = "At least one of `log_categories`, `log_groups`, or `metric_categories` must be non-empty for every diagnostic setting."
  }
}

variable "enable_telemetry" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see <https://aka.ms/avm/telemetryinfo>.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
  nullable    = false
}

variable "lock" {
  type = object({
    kind  = string
    name  = optional(string, null)
    notes = optional(string, null)
  })
  default     = null
  description = <<DESCRIPTION
Controls the Resource Lock configuration for this resource. The following properties can be specified:

- `kind` - (Required) The type of lock. Possible values are `\"CanNotDelete\"` and `\"ReadOnly\"`.
- `name` - (Optional) The name of the lock. If not specified, a name will be generated based on the `kind` value. Changing this forces the creation of a new resource.
- `notes` - (Optional) The notes recorded on the lock. If not specified, the AzureRM-era default for the `kind` is used -- `\"Cannot delete the resource or its child resources.\"` for `CanNotDelete`, `\"Cannot delete or modify the resource or its child resources.\"` for `ReadOnly` -- so an existing lock keeps the notes it already had.
DESCRIPTION

  validation {
    condition     = var.lock != null ? contains(["CanNotDelete", "ReadOnly"], var.lock.kind) : true
    error_message = "Lock kind must be either `\"CanNotDelete\"` or `\"ReadOnly\"`."
  }
}

variable "role_assignments" {
  type = map(object({
    role_definition_id_or_name             = string
    principal_id                           = string
    name                                   = optional(string, null)
    description                            = optional(string, null)
    skip_service_principal_aad_check       = optional(bool, false)
    condition                              = optional(string, null)
    condition_version                      = optional(string, null)
    delegated_managed_identity_resource_id = optional(string, null)
    principal_type                         = optional(string, null)
  }))
  default     = {}
  description = <<DESCRIPTION
A map of role assignments to create on the Azure Bastion Host and, when this module creates one, on its public IP address. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.

- `role_definition_id_or_name` - The ID or name of the role definition to assign to the principal.
- `principal_id` - The ID of the principal to assign the role to.
- `name` - (Optional) The name of the role assignment, which must be a lowercase GUID. If not set, a random UUID is generated. Changing this forces the creation of a new resource.
- `description` - (Optional) The description of the role assignment.
- `skip_service_principal_aad_check` - (Optional) If set to true, skips the Azure Active Directory check for the service principal in the tenant. Defaults to false.
- `condition` - (Optional) The condition which will be used to scope the role assignment.
- `condition_version` - (Optional) The version of the condition syntax. Leave as `null` if you are not using a condition, if you are then valid values are '2.0'.
- `delegated_managed_identity_resource_id` - (Optional) The delegated Azure Resource Id which contains a Managed Identity. Changing this forces a new resource to be created. This field is only used in cross-tenant scenario.
- `principal_type` - (Optional) The type of the `principal_id`. Possible values are `User`, `Group` and `ServicePrincipal`. It is necessary to explicitly set this attribute when creating role assignments if the principal creating the assignment is constrained by ABAC rules that filters on the PrincipalType attribute.

> Note: only set `skip_service_principal_aad_check` to true if you are assigning a role to a service principal.

> ⚠️ `skip_service_principal_aad_check` HAS NO EFFECT since this module moved to AzAPI. It mapped to an AzureRM-only client-side retry loop, not to anything on the ARM wire, and `Azure/avm-utl-interfaces/azure` 0.6.0 does not emit it. The attribute is retained so that existing configurations keep parsing; a role assignment against a freshly created service principal may now need a `depends_on` or a `time_sleep` instead. Removing it is a breaking change and is deferred to the next major.

> ⚠️ `name` was ADDED by the AzAPI migration and exists for a specific reason: AzAPI addresses a role assignment by its GUID name, whereas AzureRM generated one server-side. It is the documented escape hatch for pinning an existing assignment's GUID so that an upgrade adopts rather than recreates it. The `moved` blocks in `main.interfaces.tf` already preserve every assignment this module itself created, so `name` is only needed when reconciling an assignment that arrived some other way.
DESCRIPTION
  nullable    = false

  validation {
    condition = alltrue([
      for ra in var.role_assignments :
      ra.name == null || can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", ra.name))
    ])
    error_message = "Each role_assignments `name`, when supplied, must be a valid lowercase GUID (e.g. 11111111-1111-1111-1111-111111111111)."
  }
}

variable "tags" {
  type        = map(string)
  default     = null
  description = "(Optional) Tags of the resource."
}
