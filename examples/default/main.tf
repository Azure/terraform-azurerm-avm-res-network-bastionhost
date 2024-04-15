

variable "enable_telemetry" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see https://aka.ms/avm/telemetryinfo.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
}


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
  name               = "my_bastion"
  location           = azurerm_resource_group.this.location
  copy_paste_enabled = true
  file_copy_enabled  = false
  sku                = "Standard"
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
}






