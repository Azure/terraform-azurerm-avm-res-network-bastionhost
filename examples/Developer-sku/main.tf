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

## Section to provide a random Azure region for the resource group.
#
# 🔴 REPLACES `module "regions"` (`Azure/regions/azurerm` 0.8.2). That module is not
# AzAPI-only: it declares `hashicorp/azurerm >= 3.74.0` in its own `required_providers`
# and reads `data "azurerm_client_config" "current"` to build the resource IDs it
# returns. Keeping it would have kept a live `azurerm` data source in this example.
#
# The hardcoded list below is the same one the other four examples already use, so the
# repository is now consistent, and it is a NARROWING: the old code picked uniformly
# from every region the subscription can see, whereas Bastion Developer SKU is offered
# in a subset. Narrow this list further if a Developer deployment is rejected in one of
# these regions.
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
resource "random_integer" "region_index" {
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
  location  = element(local.regions, random_integer.region_index.result)
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
}

module "azure_bastion" {
  source = "../../"

  location         = azapi_resource.rg.location
  name             = module.naming.bastion_host.name_unique
  parent_id        = azapi_resource.rg.id
  enable_telemetry = var.enable_telemetry
  sku              = "Developer"
  tags = {
    environment = "production"
  }
  virtual_network_id = module.virtualnetwork.resource_id
  zones              = []
}
