terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.12"
    }
    # tflint-ignore: terraform_unused_required_providers
    modtm = {
      source  = "registry.terraform.io/azure/modtm"
      version = "~> 0.3"
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
# Bastion Developer SKU is offered in a subset of regions. Narrow this list if a
# deployment is rejected in one of them.
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
  source  = "Azure/avm-utl-naming/azure"
  version = "0.2.0"
}

# Supplies the subscription ID for the resource group below.
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
