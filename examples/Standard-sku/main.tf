terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.12"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
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
  version = "= 0.4.2"
}

# Supplies the subscription ID that the resource group below hangs off. Replaces
# `data.azurerm_client_config`, which the AzureRM resource group did not need only
# because AzureRM took the subscription implicitly from its provider block.
data "azapi_client_config" "current" {}

resource "azapi_resource" "rg" {
  location  = element(local.regions, random_integer.region.result)
  name      = module.naming.resource_group.name_unique
  parent_id = "/subscriptions/${data.azapi_client_config.current.subscription_id}"
  type      = "Microsoft.Resources/resourceGroups@2021-04-01"
}

module "virtualnetwork" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "= 0.22.2"

  location         = azapi_resource.rg.location
  parent_id        = azapi_resource.rg.id
  address_space    = ["10.0.0.0/16"]
  enable_telemetry = var.enable_telemetry
  name             = module.naming.virtual_network.name_unique
  subnets = {
    AzureBastionSubnet = {
      name             = "AzureBastionSubnet"
      address_prefixes = ["10.0.0.0/24"]
    }
  }
}

# The zones here MUST match the Bastion host's `zones`, which defaults to
# ["1", "2", "3"]; the module enforces that with a `lifecycle.precondition`.
# Note the type change from the AzureRM resource: `zones` was `[1, 2, 3]` (numbers,
# which AzureRM stringified on the wire) and the ARM payload is an array of strings.
resource "azapi_resource" "example_public_ip" {
  location  = azapi_resource.rg.location
  name      = module.naming.public_ip.name_unique
  parent_id = azapi_resource.rg.id
  type      = "Microsoft.Network/publicIPAddresses@2024-05-01"
  body = {
    sku = {
      name = "Standard"
    }
    zones = ["1", "2", "3"]
    properties = {
      publicIPAllocationMethod = "Static"
    }
  }
  tags = {
    environment = "Production"
  }
}

module "azure_bastion" {
  source = "../../"

  location           = azapi_resource.rg.location
  name               = module.naming.bastion_host.name_unique
  parent_id          = azapi_resource.rg.id
  copy_paste_enabled = false
  enable_telemetry   = var.enable_telemetry
  file_copy_enabled  = false
  ip_configuration = {
    name                 = "my-ipconfig"
    subnet_id            = module.virtualnetwork.subnets["AzureBastionSubnet"].resource_id
    public_ip_address_id = azapi_resource.example_public_ip.id
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
