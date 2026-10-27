mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/bastionHosts/test-bastion"
      output = {
        properties = {
          dnsName = "test-bastion.bastion.azure.com"
        }
      }
    }
  }
  mock_data "azapi_client_config" {
    defaults = {
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }
  mock_data "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/publicIPAddresses/existing-pip"
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
  name             = "test-bastion"
  parent_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test"
  ip_configuration = {
    subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/virtualNetworks/test/subnets/AzureBastionSubnet"
  }
}

run "basic_creates_public_ip" {
  command = apply

  assert {
    condition     = length(azapi_resource.bastion) == 1 && length(azapi_resource.bastion_developer) == 0 && length(module.public_ip_address) == 1
    error_message = "Basic Bastion must create one host and one public IP."
  }

  assert {
    condition     = azapi_resource.bastion[0].body.properties.ipConfigurations[0].properties.publicIPAddress.id == module.public_ip_address[0].resource_id
    error_message = "The host must use the public IP created by the module."
  }

  assert {
    condition     = output.resource_id == azapi_resource.bastion[0].id && output.dns_name == "test-bastion.bastion.azure.com"
    error_message = "The resource ID and DNS output must identify the selected host."
  }
  providers = {
    azapi  = azapi
    modtm  = modtm
    random = random
  }
}

run "developer_uses_virtual_network" {
  command = apply

  variables {
    sku                = "Developer"
    ip_configuration   = null
    virtual_network_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/virtualNetworks/test"
    zones              = []
  }

  assert {
    condition     = length(azapi_resource.bastion) == 0 && length(azapi_resource.bastion_developer) == 1 && length(module.public_ip_address) == 0 && length(data.azapi_resource.public_ip) == 0
    error_message = "Developer Bastion must not create or look up a public IP."
  }

  assert {
    condition     = azapi_resource.bastion_developer[0].body.properties.virtualNetwork.id == var.virtual_network_id && output.resource_id == azapi_resource.bastion_developer[0].id
    error_message = "Developer Bastion must use the supplied virtual network and expose its own ID."
  }
  providers = {
    azapi  = azapi
    modtm  = modtm
    random = random
  }
}

run "standard_uses_existing_public_ip" {
  command = apply

  variables {
    sku                    = "Standard"
    copy_paste_enabled     = false
    file_copy_enabled      = true
    ip_connect_enabled     = true
    kerberos_enabled       = true
    scale_units            = 4
    shareable_link_enabled = true
    tunneling_enabled      = true
    ip_configuration = {
      subnet_id            = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/virtualNetworks/test/subnets/AzureBastionSubnet"
      create_public_ip     = false
      public_ip_address_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/publicIPAddresses/existing-pip"
    }
  }

  assert {
    condition     = length(module.public_ip_address) == 0 && length(data.azapi_resource.public_ip) == 1 && azapi_resource.bastion[0].body.properties.ipConfigurations[0].properties.publicIPAddress.id == var.ip_configuration.public_ip_address_id
    error_message = "The host must use the existing public IP without creating another."
  }

  assert {
    condition     = azapi_resource.bastion[0].body.properties.disableCopyPaste && azapi_resource.bastion[0].body.properties.enableFileCopy && azapi_resource.bastion[0].body.properties.enableIpConnect && azapi_resource.bastion[0].body.properties.enableKerberos && azapi_resource.bastion[0].body.properties.enableShareableLink && azapi_resource.bastion[0].body.properties.enableTunneling && azapi_resource.bastion[0].body.properties.scaleUnits == 4
    error_message = "Standard Bastion feature settings must be applied to the host."
  }
  providers = {
    azapi  = azapi
    modtm  = modtm
    random = random
  }
}

run "premium_private_only" {
  command = apply

  variables {
    sku                       = "Premium"
    private_only_enabled      = true
    session_recording_enabled = true
    ip_configuration = {
      subnet_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/virtualNetworks/test/subnets/AzureBastionSubnet"
      create_public_ip = false
    }
  }

  assert {
    condition     = length(module.public_ip_address) == 0 && length(data.azapi_resource.public_ip) == 0 && azapi_resource.bastion[0].body.properties.ipConfigurations[0].properties.publicIPAddress == null
    error_message = "Private-only Bastion must not create, read, or attach a public IP."
  }

  assert {
    condition     = azapi_resource.bastion[0].body.properties.enablePrivateOnlyBastion && azapi_resource.bastion[0].body.properties.enableSessionRecording
    error_message = "Private-only and session recording settings must be applied."
  }
  providers = {
    azapi  = azapi
    modtm  = modtm
    random = random
  }
}

run "rejects_public_ip_zone_mismatch" {
  command = plan

  variables {
    zones = ["1"]
    ip_configuration = {
      subnet_id            = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/virtualNetworks/test/subnets/AzureBastionSubnet"
      create_public_ip     = false
      public_ip_address_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/publicIPAddresses/existing-pip"
    }
  }

  expect_failures = [azapi_resource.bastion]
  providers = {
    azapi  = azapi
    modtm  = modtm
    random = random
  }
}

run "rejects_incompatible_session_recording" {
  command = plan

  variables {
    sku                       = "Premium"
    session_recording_enabled = true
    tunneling_enabled         = true
  }

  expect_failures = [var.tunneling_enabled]
  providers = {
    azapi  = azapi
    modtm  = modtm
    random = random
  }
}
