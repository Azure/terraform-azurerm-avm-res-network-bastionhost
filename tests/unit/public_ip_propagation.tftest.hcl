mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/bastionHosts/bastion-test"
    }
  }
}
mock_provider "modtm" {}
mock_provider "random" {}

variables {
  enable_telemetry = false
  location         = "eastus"
  name             = "bastion-propagation"
  parent_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
  ip_configuration = {
    subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/AzureBastionSubnet"
  }
  resource_types = {
    public_ip_address = {
      network_public_ip_addresses = "Microsoft.Network/publicIPAddresses@2024-05-01"
      resources_tags              = "Microsoft.Resources/tags@2021-04-01"
    }
  }
  ignore_body_changes = {
    network_bastion_hosts = ["properties.scaleUnits"]
    public_ip_address = {
      network_public_ip_addresses = ["properties.ipTags"]
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

run "apply_child_controls" {
  command = apply

  assert {
    condition     = length(module.public_ip_address) == 1
    error_message = "The propagation fixture must exercise the owned public IP child."
  }
}
