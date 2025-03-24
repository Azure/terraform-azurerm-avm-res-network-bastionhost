# Azure Verified Module for Azure Bastion

This module provides a generic way to create and manage a Azure Bastion resource.

To use this module in your Terraform configuration, you'll need to provide values for the required variables.

## Features

The module supports the `Developer`, `Basic`, `Standard` and `Premium` SKU's for Azure Bastion.


## Example Usage

Here is an example of how you can use this module in your Terraform configuration:

```terraform
module "azure_bastion" {
  source = "Azure/avm-res-network-bastionhost/azurerm"

  enable_telemetry    = true
  name                = module.naming.bastion_host.name_unique
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  copy_paste_enabled  = true
  file_copy_enabled   = false
  sku                 = "Standard"
  ip_configuration = {
    name                 = "my-ipconfig"
    subnet_id            = module.virtualnetwork.subnets["AzureBastionSubnet"].resource_id
    public_ip_address_id = azurerm_public_ip.example.id
  }
  ip_connect_enabled     = true
  scale_units            = 4
  shareable_link_enabled = true
  tunneling_enabled      = true
  kerberos_enabled       = true

  tags = {
    environment = "production"
  }
}
```

## AVM Versioning Notice

Major version Zero (0.y.z) is for initial development. Anything MAY change at any time. The module SHOULD NOT be considered stable till at least it is major version one (1.0.0) or greater. Changes will always be via new versions being published and no changes will be made to existing published versions. For more details please go to <https://semver.org/>
