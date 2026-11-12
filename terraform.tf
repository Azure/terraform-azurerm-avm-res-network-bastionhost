terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.12"
    }
  }
}

# This module and everything it calls are AzAPI-only; no `azurerm` provider is required.
# The child modules declare the `modtm` and `random` providers they need.
