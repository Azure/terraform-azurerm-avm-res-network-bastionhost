# Azure Verified Module for Azure Bastion

This module provides a generic way to create and manage a Azure Bastion resource.

To use this module in your Terraform configuration, you'll need to provide values for the required variables.

## Features

The module supports the `Developer`, `Basic`, `Standard` and `Premium` SKU's for Azure Bastion.


## Example Usage

Here is an example of how you can use this module in your Terraform configuration:

```terraform
resource "azapi_resource" "rg" {
  type      = "Microsoft.Resources/resourceGroups@2021-04-01"
  parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
  name      = "rg-bastion-example"
  location  = "westeurope"
}

resource "azapi_resource" "example_public_ip" {
  type      = "Microsoft.Network/publicIPAddresses@2024-05-01"
  parent_id = azapi_resource.rg.id
  name      = "pip-bastion-example"
  location  = azapi_resource.rg.location
  body = {
    sku   = { name = "Standard" }
    zones = ["1", "2", "3"]
    properties = {
      publicIPAllocationMethod = "Static"
    }
  }
}

module "azure_bastion" {
  source = "Azure/avm-res-network-bastionhost/azurerm"

  enable_telemetry   = true
  name               = "bas-example"
  parent_id          = azapi_resource.rg.id
  location           = azapi_resource.rg.location
  copy_paste_enabled = true
  file_copy_enabled  = false
  sku                = "Standard"
  ip_configuration = {
    name                 = "my-ipconfig"
    subnet_id            = module.virtualnetwork.subnets["AzureBastionSubnet"].resource_id
    public_ip_address_id = azapi_resource.example_public_ip.id
    create_public_ip     = false
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

> The zones on a public IP you supply yourself must match the Bastion host's
> `zones` (default `["1", "2", "3"]`). The module enforces that with a
> `lifecycle.precondition` rather than letting ARM reject the deployment.

## Upgrading from an AzureRM release

This module is built on `Azure/azapi`. Most existing deployments move state to
the AzAPI resources through in-module `moved` blocks. A deployment created with
v0.6.0 or earlier and `sku = "Developer"` is an exception and recreates the
Bastion host. See the breaking-change note below.

Plan the upgrade with Terraform's default refresh. Review the plan before
applying it, especially if the deployment uses the affected Developer SKU path.

One cohort cannot be carried across declaratively: a deployment created at
**v0.6.0 or earlier with `sku = "Developer"`**. Terraform allows each source
address exactly one `moved` destination, and `azurerm_bastion_host.this` had no
`count`, so its single slot is spent on the non-Developer path. Those
deployments see a destroy and recreate.

### Breaking change: `sku = "Developer"` upgraded from v0.6.0 or earlier

**Who is affected:** only a consumer whose state was created by
`Azure/avm-res-network-bastionhost/azurerm` **v0.6.0 or earlier** and who sets
`sku = "Developer"`. Every other combination upgrades in place.

**What happens:** `terraform plan` shows the Bastion host **destroyed and
recreated**, not moved. The host's public endpoint and its resource ID change,
and connectivity is interrupted for the duration of the recreate.

**Why it cannot be fixed here:** Terraform permits each `moved` *source* address
exactly one destination. `azurerm_bastion_host.this` in v0.6.0 has no `count`,
so it is a single instance with a single move slot. This release has two
mutually exclusive writers: `azapi_resource.bastion[0]` and
`azapi_resource.bastion_developer[0]`. The slot is allocated to
`azapi_resource.bastion[0]`, the non-Developer path. A second `moved` block from the same source is a
static plan-time error (`Ambiguous move statements`), not a runtime choice, so
both cohorts cannot be served. `terraform state mv` is not an escape either: it
refuses to move state between different resource types.

**This break is inherited, not introduced.** Upstream v0.7.0 already replaced
`azurerm_bastion_host` with `azapi_resource` and shipped **no** `moved` blocks at
all, so this path was already broken in 2025 and no declarative move can reclaim
it. This release repairs three of the four cohorts; it cannot repair the fourth.

**What to do:** accept the recreate during a maintenance window, or upgrade to
v0.7.0 through v0.9.0 first. This release keeps the upstream resource labels,
so the Developer path needs no state move and upgrades in place when upgrading
from those versions.

### `hashicorp/azurerm` is no longer required at all

This module is AzAPI-only, in its own code **and** in its dependency graph.
`terraform init` installs `Azure/azapi`, `azure/modtm` and `hashicorp/random`
and nothing else; `hashicorp/azurerm` does not appear in `.terraform.lock.hcl`.

The last AzureRM dependency was `module.public_ip_address`
(`Azure/avm-res-network-publicipaddress/azurerm`), which carried
`azurerm >= 3.116, < 5.0` in its own `required_providers`. Its AzAPI version is
AzAPI-only, so that requirement is gone and with it the widened floor that
earlier notes described.

Two consequences for a consumer:

- **You may delete `provider "azurerm" { features {} }` from your root
  configuration**, if it was there only for this module. It is no longer needed
  even when this module creates a public IP.
- **The public IP module's own input changed.** The AzAPI version deleted
  `resource_group_name` and replaced it with a required `parent_id` taking the
  fully-qualified resource-group ID. This module absorbs that internally. It
  forwards its own `var.parent_id`, so nothing in *your* configuration changes.


## AVM Versioning Notice

Major version Zero (0.y.z) is for initial development. Anything MAY change at any time. The module SHOULD NOT be considered stable till at least it is major version one (1.0.0) or greater. Changes will always be via new versions being published and no changes will be made to existing published versions. For more details please go to <https://semver.org/>
