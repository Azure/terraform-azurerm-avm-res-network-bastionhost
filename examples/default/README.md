<!-- BEGIN_TF_DOCS -->

# Create a Azure Bastion Resource

This deploys the module in its simplest form.

```hcl

# This is required for resource modules
resource "azurerm_resource_group" "this" {
  location = "eastasia"
  name     = "bastion-rg"
}
# Using the AVM module for virtual network
module "virtualnetwork" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.1.3"

  vnet_name                     = "management-vnet"
  enable_telemetry              = true
  resource_group_name           = azurerm_resource_group.this.name
  vnet_location                 = "eastasia"
  virtual_network_address_space = ["10.0.0.0/16"]
  subnets = {
    AzureBastionSubnet = {
      name             = "AzureBastionSubnet"
      address_prefixes = ["10.0.1.0/24"]
    }
  }
}

resource "azurerm_public_ip" "example" {
  allocation_method   = "Static"
  location            = azurerm_resource_group.this.location
  name                = "acceptanceTestPublicIp1"
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "Standard"
  tags = {
    environment = "Production"
  }
}



# This is the module call
module "azure_bastion" {
  source = "../../"

  // Pass in the required variables from the module
  enable_telemetry     = true
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = module.virtualnetwork.vnet-resource.name

  // Define the bastion host configuration
  bastion_host = {
    name                = "my-bastion"
    resource_group_name = azurerm_resource_group.this.name
    location            = "eastasia"
    copy_paste_enabled  = true
    file_copy_enabled   = false
    sku                 = "Standard"
    ip_configuration = {
      name                 = "my-ipconfig"
      subnet_id            = module.virtualnetwork.subnets["AzureBastionSubnet"].id
      public_ip_address_id = azurerm_public_ip.example.id
    }
    ip_connect_enabled     = true
    scale_units            = 2
    shareable_link_enabled = true
    tunneling_enabled      = true
    tags = {
      environment = "production"
    }

    lock = {
      name = "my-lock"
      kind = "ReadOnly"

    }
    diagnostic_settings = {
      diag_setting_1 = {
        name                                     = "diagSetting1"
        log_groups                               = ["allLogs"]
        metric_categories                        = ["AllMetrics"]
        log_analytics_destination_type           = "Dedicated"
        workspace_resource_id                    = "/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.OperationalInsights/workspaces/{workspaceName}"
        storage_account_resource_id              = "/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Storage/storageAccounts/{storageAccountName}"
        event_hub_authorization_rule_resource_id = "/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.EventHub/namespaces/{namespaceName}/eventhubs/{eventHubName}/authorizationrules/{authorizationRuleName}"
        event_hub_name                           = "{eventHubName}"
        marketplace_partner_resource_id          = "/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/{partnerResourceProvider}/{partnerResourceType}/{partnerResourceName}"
      }
    }




  }
}






```

<!-- markdownlint-disable MD033 -->
## Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) (>= 1.0.0)

- <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) (>= 3.7.0, < 4.0.0)

## Providers

The following providers are used by this module:

- <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) (>= 3.7.0, < 4.0.0)

## Resources

The following resources are used by this module:

- [azurerm_public_ip.example](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) (resource)
- [azurerm_resource_group.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) (resource)

<!-- markdownlint-disable MD013 -->
## Required Inputs

No required inputs.

## Optional Inputs

No optional inputs.

## Outputs

The following outputs are exported:

### <a name="output_bastion_host"></a> [bastion\_host](#output\_bastion\_host)

Description: The name of the bastion host resource

### <a name="output_bastion_host_id"></a> [bastion\_host\_id](#output\_bastion\_host\_id)

Description: The id of the bastion host resource

## Modules

The following Modules are called:

### <a name="module_azure_bastion"></a> [azure\_bastion](#module\_azure\_bastion)

Source: ../../

Version:

### <a name="module_virtualnetwork"></a> [virtualnetwork](#module\_virtualnetwork)

Source: Azure/avm-res-network-virtualnetwork/azurerm

Version: 0.1.3

<!-- markdownlint-disable-next-line MD041 -->
## Data Collection

The software may collect information about you and your use of the software and send it to Microsoft. Microsoft may use this information to provide services and improve our products and services. You may turn off the telemetry as described in the repository. There are also some features in the software that may enable you and Microsoft to collect data from users of your applications. If you use these features, you must comply with applicable law, including providing appropriate notices to users of your applications together with a copy of Microsoft’s privacy statement. Our privacy statement is located at <https://go.microsoft.com/fwlink/?LinkID=824704>. You can learn more about data collection and use in the help documentation and our privacy statement. Your use of the software operates as your consent to these practices.

---

## AVM Versioning Notice

Major version Zero (0.y.z) is for initial development. Anything MAY change at any time. The module SHOULD NOT be considered stable till at least it is major version one (1.0.0) or greater. Changes will always be via new versions being published and no changes will be made to existing published versions. For more details please go to <https://semver.org/>
<!-- END_TF_DOCS -->