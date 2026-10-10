terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.12"
    }
    modtm = {
      source  = "azure/modtm"
      version = "~> 0.3"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

# `hashicorp/azurerm` IS ABSENT, AND THIS MODULE IS NOW GENUINELY AZURERM-FREE.
#
# This module declares no `azurerm_*` resource and no `azurerm_*` data source, and as of
# the AzAPI release of `Azure/avm-res-network-publicipaddress/azurerm` neither does
# anything it calls. `module.public_ip_address` in `main.tf` is the module that used to
# carry `azurerm >= 3.116, < 5.0` in its own `required_providers` and force Terraform to
# install and configure the provider on its behalf; its AzAPI release drops that
# requirement entirely.
#
# MEASURED, not assumed. `terraform init -upgrade` in this root resolves exactly three
# providers -- `azure/azapi`, `azure/modtm`, `hashicorp/random` -- and `.terraform.lock.hcl`
# contains three `provider` blocks with no `registry.terraform.io/hashicorp/azurerm` among
# them. The previously recorded line `Finding hashicorp/azurerm versions matching
# ">= 3.116.0, < 5.0.0"` no longer appears in the init output.
#
# THE WIDENED-FLOOR CAVEAT IS RESOLVED, NOT MITIGATED. An earlier revision of this file
# warned that deleting the root's `azurerm ~> 4.10` entry widened the effective constraint
# to the child module's `>= 3.116, < 5.0`, so a consumer with no pin could resolve an
# azurerm 3.x. There is no longer any azurerm constraint anywhere in this graph, so there
# is nothing left to widen and no pin is needed. Do not re-add one: a module that declares
# no `azurerm_*` block has no standing to pin the provider, and
# `terraform_unused_required_providers` would reject the entry anyway.
#
# WHAT A CONSUMER NO LONGER HAS TO DO: supply `provider "azurerm" { features {} }`. That
# block was required whenever this module created a public IP, because AzureRM refuses to
# initialise without a `features` block and an implicit empty provider configuration does
# not have one. All five examples have had it removed, along with the `azurerm` entry in
# their own `required_providers` and the `avm.tflint_example.override.hcl` that existed
# solely to stop `avm_provider_azurerm_disallowed` firing on them.
#
# Deliberately NOT done here: inlining the public IP as an `azapi_resource`. That is a
# COMPOSITION migration -- it moves a resource across a module boundary -- and combining
# it with the provider migration would make the `moved` blocks in `main.tf` and
# `main.interfaces.tf` unable to preserve state. The public IP's own provider hop is
# handled by `moved` blocks INSIDE that module, where the addresses actually live. See
# "Separate two changes" in `.github/skills/avm-tf-migration/SKILL.md`.
