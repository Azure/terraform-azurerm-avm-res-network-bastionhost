terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.10"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azapi" {

}

## Section to provide a random Azure region for the resource group. The bellow regions currently support Zone Redundant Bastion.
# This allows us to randomize the region for the resource group.
locals {
  regions = [
    "Canada Central", "North Europe", "South Africa North", "Australia East",
    "Central US", "Sweden Central", "Israel Central", "Korea Central",
    "East US", "UK South",
    "East US 2", "West Europe",
    "West US 2", "Norway East", "Italy North",
    "Mexico Central", "Spain Central"
  ]
}

# This allows us to randomize the region for the resource group.
resource "random_integer" "region" {
  max = length(local.regions) - 1
  min = 0
}
## End of section to provide a random Azure region for the resource group

module "naming" {
  source  = "Azure/naming/azurerm"
  version = "~> 0.3"
}

resource "azurerm_resource_group" "this" {
  location = element(local.regions, random_integer.region.result)
  name     = module.naming.resource_group.name_unique
}

module "virtualnetwork" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "~> 0.2"

  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  enable_telemetry    = false
  name                = module.naming.virtual_network.name_unique
  subnets = {
    AzureBastionSubnet = {
      name             = "AzureBastionSubnet"
      address_prefixes = ["10.0.0.0/24"]
    }
  }
}

resource "azurerm_public_ip" "example" {
  allocation_method   = "Static"
  location            = azurerm_resource_group.this.location
  name                = module.naming.public_ip.name_unique
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "Standard"
  tags = {
    environment = "Production"
  }
  zones = [1, 2, 3]
}

module "azure_bastion" {
  source = "../../"

  location            = azurerm_resource_group.this.location
  name                = module.naming.bastion_host.name_unique
  resource_group_name = azurerm_resource_group.this.name
  copy_paste_enabled  = false
  enable_telemetry    = true
  file_copy_enabled   = false
  ip_configuration = {
    name                 = "my-ipconfig"
    subnet_id            = module.virtualnetwork.subnets["AzureBastionSubnet"].resource_id
    public_ip_address_id = azurerm_public_ip.example.id
    create_public_ip     = false
  }
  ip_connect_enabled     = true
  kerberos_enabled       = true
  scale_units            = 4
  shareable_link_enabled = true
  sku                    = "Standard"
  tags = {
    environment = "production"
  }
  tunneling_enabled = true
}
