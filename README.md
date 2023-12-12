<!-- BEGIN_TF_DOCS -->
### Azure Verified Module for Azure Bastion

This module provides a generic way to create and manage a Azure Bastion resource.

To use this module in your Terraform configuration, you'll need to provide values for the required variables. Here's a basic example:

module "azure\_bastion" {
  source = "./path\_to\_this\_module"

  enable\_telemetry     = true
  resource\_group\_name  = azurerm\_resource\_group.this.name
  virtual\_network\_name = azurerm\_virtual\_network.example.name

  // Define the bastion host configuration
  bastion\_host = {
    name                = "my-bastion"
    resource\_group\_name = azurerm\_resource\_group.this.name
    location            = "southeastasia"
    copy\_paste\_enabled  = true
    file\_copy\_enabled   = false
    sku                 = "Basic"
    ip\_configuration = {
      name                 = "my-ipconfig"
      subnet\_id            = "subnet\_id\_resource"
      public\_ip\_address\_id = azurerm\_public\_ip.example.id
    }
    ip\_connect\_enabled     = true
    scale\_units            = 2
    shareable\_link\_enabled = true
    tunneling\_enabled      = true
  }

<!-- markdownlint-disable MD033 -->
## Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) (>= 1.0.0)

- <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) (>= 3.71.0)

- <a name="requirement_random"></a> [random](#requirement\_random) (>= 3.5.0)

## Providers

The following providers are used by this module:

- <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) (>= 3.71.0)

- <a name="provider_random"></a> [random](#provider\_random) (>= 3.5.0)

## Resources

The following resources are used by this module:

- [azurerm_bastion_host.bastion](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/bastion_host) (resource)
- [azurerm_management_lock.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/management_lock) (resource)
- [azurerm_monitor_diagnostic_setting.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_diagnostic_setting) (resource)
- [azurerm_resource_group_template_deployment.telemetry](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group_template_deployment) (resource)
- [azurerm_role_assignment.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) (resource)
- [random_id.telem](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) (resource)

<!-- markdownlint-disable MD013 -->
## Required Inputs

The following input variables are required:

### <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name)

Description: The name of the resource group in which to create the Azure Bastion.

Type: `string`

### <a name="input_virtual_network_name"></a> [virtual\_network\_name](#input\_virtual\_network\_name)

Description: The name of the virtual network where Azure Bastion will be deployed.

Type: `string`

## Optional Inputs

The following input variables are optional (have default values):

### <a name="input_bastion_host"></a> [bastion\_host](#input\_bastion\_host)

Description: Configuration for Azure Bastion Host

Type:

```hcl
object({
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
    tags                   = map(string)
  })
```

Default:

```json
{
  "copy_paste_enabled": true,
  "file_copy_enabled": false,
  "ip_configuration": {
    "name": "example-ipconfig",
    "public_ip_address_id": "public-ip-id",
    "subnet_id": "subnet-id"
  },
  "ip_connect_enabled": false,
  "location": "West Europe",
  "name": "example-bastion",
  "resource_group_name": "example-resources",
  "scale_units": 2,
  "shareable_link_enabled": false,
  "sku": "Standard",
  "tags": {},
  "tunneling_enabled": false
}
```

### <a name="input_diagnostic_settings"></a> [diagnostic\_settings](#input\_diagnostic\_settings)

Description:   A map of diagnostic settings to create on the Key Vault. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.

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

Type:

```hcl
map(object({
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
```

Default: `{}`

### <a name="input_enable_telemetry"></a> [enable\_telemetry](#input\_enable\_telemetry)

Description: This variable controls whether or not telemetry is enabled for the module.  
For more information see https://aka.ms/avm/telemetryinfo.  
If it is set to false, then no telemetry will be collected.

Type: `bool`

Default: `true`

### <a name="input_lock"></a> [lock](#input\_lock)

Description: The lock level to apply to the Key Vault. Possible values are `None`, `CanNotDelete`, and `ReadOnly`.

Type:

```hcl
object({
    name = optional(string, null)
    kind = optional(string, "None")
  })
```

Default: `{}`

### <a name="input_role_assignments"></a> [role\_assignments](#input\_role\_assignments)

Description:   A map of role assignments to create on the Key Vault. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.

  - `role_definition_id_or_name` - The ID or name of the role definition to assign to the principal.
  - `principal_id` - The ID of the principal to assign the role to.
  - `description` - The description of the role assignment.
  - `skip_service_principal_aad_check` - If set to true, skips the Azure Active Directory check for the service principal in the tenant. Defaults to false.
  - `condition` - The condition which will be used to scope the role assignment.
  - `condition_version` - The version of the condition syntax. Leave as `null` if you are not using a condition, if you are then valid values are '2.0'.

  > Note: only set `skip_service_principal_aad_check` to true if you are assigning a role to a service principal.

Type:

```hcl
map(object({
    role_definition_id_or_name             = string
    principal_id                           = string
    description                            = optional(string, null)
    skip_service_principal_aad_check       = optional(bool, false)
    condition                              = optional(string, null)
    condition_version                      = optional(string, null)
    delegated_managed_identity_resource_id = optional(string, null)
  }))
```

Default: `{}`

### <a name="input_subnet_name"></a> [subnet\_name](#input\_subnet\_name)

Description: The name of the subnet

Type: `string`

Default: `"AzureBastionSubnet"`

### <a name="input_tags"></a> [tags](#input\_tags)

Description: n/a

Type: `map(any)`

Default: `{}`

## Outputs

The following outputs are exported:

### <a name="output_bastion-resource"></a> [bastion-resource](#output\_bastion-resource)

Description: The Azure Bastion resource

## Modules

No modules.

<!-- markdownlint-disable-next-line MD041 -->
## Data Collection

The software may collect information about you and your use of the software and send it to Microsoft. Microsoft may use this information to provide services and improve our products and services. You may turn off the telemetry as described in the repository. There are also some features in the software that may enable you and Microsoft to collect data from users of your applications. If you use these features, you must comply with applicable law, including providing appropriate notices to users of your applications together with a copy of Microsoft’s privacy statement. Our privacy statement is located at <https://go.microsoft.com/fwlink/?LinkID=824704>. You can learn more about data collection and use in the help documentation and our privacy statement. Your use of the software operates as your consent to these practices.

---

## AVM Versioning Notice
Major version Zero (0.y.z) is for initial development. Anything MAY change at any time. The module SHOULD NOT be considered stable till at least it is major version one (1.0.0) or greater. Changes will always be via new versions being published and no changes will be made to existing published versions. For more details please go to https://semver.org/
<!-- END_TF_DOCS -->