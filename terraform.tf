terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.12"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.10"
    }
    # tflint-ignore: terraform_unused_required_providers
    modtm = {
      source  = "azure/modtm"
      version = "~> 0.3"
    }
  }
}
