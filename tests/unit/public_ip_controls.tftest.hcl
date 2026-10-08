mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/bastionHosts/bastion-test"
      output = {
        properties = {
          dnsName = "bastion-test.example"
        }
      }
    }
  }
  mock_data "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/publicIPAddresses/pip-existing"
      output = {
        zones = ["1", "2", "3"]
      }
    }
  }
}
mock_provider "modtm" {}
mock_provider "random" {}

variables {
  enable_telemetry = false
  location         = "eastus"
  name             = "bastion-test"
  parent_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
  ip_configuration = {
    subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/AzureBastionSubnet"
  }
}

run "created_ip_defaults" {
  command = apply

  assert {
    condition     = length(module.public_ip_address) == 1 && length(data.azapi_resource.public_ip) == 0
    error_message = "The default Basic SKU must create its public IP rather than read a supplied IP."
  }
  assert {
    condition     = alltrue([for value in values(var.resource_types.public_ip_address) : value == null])
    error_message = "The parent must leave child API version defaults to the owning public IP module."
  }
  assert {
    condition     = alltrue([for paths in values(var.ignore_body_changes.public_ip_address) : length(paths) == 0])
    error_message = "The child ignore paths must default to empty lists."
  }
  assert {
    condition     = local.ignore_body_changes.network_bastion_hosts == null
    error_message = "Empty parent ignore paths must still collapse to null."
  }
}

run "created_ip_overrides" {
  command = apply

  variables {
    sku = "Standard"
    resource_types = {
      network_public_ip_addresses = "Microsoft.Network/publicIPAddresses@2024-05-01"
      public_ip_address = {
        network_public_ip_addresses    = "Microsoft.Network/publicIPAddresses@2024-05-01"
        authorization_locks            = "Microsoft.Authorization/locks@2020-05-01"
        authorization_role_assignments = "Microsoft.Authorization/roleAssignments@2022-04-01"
        insights_diagnostic_settings   = "Microsoft.Insights/diagnosticSettings@2021-05-01-preview"
        resources_tags                 = "Microsoft.Resources/tags@2021-04-01"
      }
    }
    ignore_body_changes = {
      network_bastion_hosts = ["properties.scaleUnits"]
      public_ip_address = {
        network_public_ip_addresses    = ["properties.ipTags"]
        authorization_locks            = ["properties.notes"]
        authorization_role_assignments = ["properties.description"]
        insights_diagnostic_settings   = ["properties.logs"]
      }
    }
    retry = {
      error_message_regex  = ["ExampleTransientError"]
      interval_seconds     = 7
      max_interval_seconds = 70
    }
    timeouts = {
      create = "41m"
      read   = "6m"
      update = "42m"
      delete = "43m"
    }
    tags = { environment = "test" }
  }

  assert {
    condition     = var.resource_types.public_ip_address.network_public_ip_addresses == "Microsoft.Network/publicIPAddresses@2024-05-01"
    error_message = "The child API override must not be discarded by the parent variable type."
  }
  assert {
    condition     = jsonencode(var.ignore_body_changes.public_ip_address.network_public_ip_addresses) == jsonencode(["properties.ipTags"])
    error_message = "The child ignore paths must be independent of the parent Bastion paths."
  }
  assert {
    condition     = azapi_resource.bastion[0].body.properties.ipConfigurations[0].properties.publicIPAddress.id == module.public_ip_address[0].resource_id
    error_message = "The Standard host must use the module-created public IP."
  }
}

run "created_ip_null_controls" {
  command = apply

  variables {
    resource_types = {
      public_ip_address = null
    }
    ignore_body_changes = {
      public_ip_address = null
    }
    retry    = null
    timeouts = null
  }

  assert {
    condition     = alltrue([for value in values(var.resource_types.public_ip_address) : value == null])
    error_message = "An explicit null child slot must retain the child API defaults."
  }
  assert {
    condition     = alltrue([for paths in values(var.ignore_body_changes.public_ip_address) : length(paths) == 0])
    error_message = "An explicit null child slot must ignore no body paths."
  }
  assert {
    condition     = azapi_resource.bastion[0].timeouts.create == "30m"
    error_message = "Null timeouts must retain the Bastion per-resource fallback."
  }
}

run "supplied_ip_read_type" {
  command = apply

  variables {
    sku = "Standard"
    ip_configuration = {
      subnet_id            = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/AzureBastionSubnet"
      create_public_ip     = false
      public_ip_address_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/publicIPAddresses/pip-existing"
    }
    resource_types = {
      network_public_ip_addresses = "Microsoft.Network/publicIPAddresses@2023-11-01"
      public_ip_address = {
        network_public_ip_addresses = "Microsoft.Network/publicIPAddresses@2024-05-01"
      }
    }
  }

  assert {
    condition     = length(module.public_ip_address) == 0 && length(data.azapi_resource.public_ip) == 1
    error_message = "A supplied IP must be read without creating a public IP child."
  }
  assert {
    condition     = data.azapi_resource.public_ip[0].type == "Microsoft.Network/publicIPAddresses@2023-11-01"
    error_message = "The existing top-level API version must continue to control only the supplied-IP read."
  }
  assert {
    condition     = azapi_resource.bastion[0].body.properties.ipConfigurations[0].properties.publicIPAddress.id == var.ip_configuration.public_ip_address_id
    error_message = "The host must use the supplied public IP."
  }
}

run "premium_private_only" {
  command = apply

  variables {
    sku                  = "Premium"
    private_only_enabled = true
    ip_configuration = {
      subnet_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/AzureBastionSubnet"
      create_public_ip = false
    }
  }

  assert {
    condition     = length(module.public_ip_address) == 0 && length(data.azapi_resource.public_ip) == 0
    error_message = "Private-only Premium must neither create nor read a public IP."
  }
  assert {
    condition     = azapi_resource.bastion[0].body.properties.ipConfigurations[0].properties.publicIPAddress == null
    error_message = "Private-only Premium must not attach a public IP."
  }
}

run "developer_without_ip_configuration" {
  command = apply

  variables {
    sku                = "Developer"
    ip_configuration   = null
    virtual_network_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test"
    zones              = []
  }

  assert {
    condition     = length(module.public_ip_address) == 0 && length(data.azapi_resource.public_ip) == 0
    error_message = "Developer must neither create nor read a public IP."
  }
  assert {
    condition     = length(azapi_resource.bastion) == 0 && length(azapi_resource.bastion_developer) == 1
    error_message = "Developer must use only the Developer writer."
  }
  assert {
    condition     = !can(azapi_resource.bastion_developer[0].body.properties.ipConfigurations)
    error_message = "Developer must not send an IP configuration."
  }
}
