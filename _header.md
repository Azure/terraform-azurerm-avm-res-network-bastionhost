# Azure Verified Module for Azure Bastion 

This module provides a generic way to create and manage a Azure Bastion resource.

To use this module in your Terraform configuration, you'll need to provide values for the required variables. Here's a basic example:

```
module "azure_bastion" {
  source = "./path_to_this_module"

  
  enable_telemetry     = true
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.example.name

  // Define the bastion host configuration
  bastion_host = {
    name                = "my-bastion"
    resource_group_name = azurerm_resource_group.this.name
    location            = "southeastasia"
    copy_paste_enabled  = true
    file_copy_enabled   = false
    sku                 = "Basic"
    ip_configuration = {
      name                 = "my-ipconfig"
      subnet_id            = "subnet_id_resource"
      public_ip_address_id = azurerm_public_ip.example.id
    }
    ip_connect_enabled     = true
    scale_units            = 2
    shareable_link_enabled = true
    tunneling_enabled      = true
  
  }
  ```
