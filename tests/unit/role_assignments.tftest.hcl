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
  mock_data "azapi_client_config" {
    defaults = {
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }
}

mock_provider "modtm" {}

mock_provider "random" {}

override_resource {
  target = module.public_ip_address[0].azapi_resource.this
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/publicIPAddresses/pip-bastion-test"
  }
}

# The lookup scope itself (the resource group) is set in `locals.tf` and is proven live,
# because a mocked data source cannot show which scope it was asked for.
override_data {
  target = module.interfaces.data.azapi_resource_list.role_definitions[0]
  values = {
    output = {
      results = [
        {
          id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Authorization/roleDefinitions/00000000-0000-0000-0000-000000000007"
          role_name = "RG Only Custom Role"
        },
        {
          id        = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
          role_name = "Reader"
        },
      ]
    }
  }
}

override_data {
  target = module.interfaces_public_ip.data.azapi_resource_list.role_definitions[0]
  values = {
    output = {
      results = [
        {
          id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Authorization/roleDefinitions/00000000-0000-0000-0000-000000000007"
          role_name = "RG Only Custom Role"
        },
        {
          id        = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
          role_name = "Reader"
        },
      ]
    }
  }
}

variables {
  enable_telemetry = false
  location         = "eastus"
  name             = "bastion-test"
  parent_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
  ip_configuration = {
    subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/AzureBastionSubnet"
  }
  role_assignments = {
    custom = {
      role_definition_id_or_name = "RG Only Custom Role"
      principal_id               = "00000000-0000-0000-0000-000000000004"
    }
  }
}

run "resolves_role_names_through_the_lookup" {
  command = apply

  assert {
    condition     = azapi_resource.role_assignments["custom"].body.properties.roleDefinitionId == "/subscriptions/00000000-0000-0000-0000-000000000000/resourcegroups/rg-test/providers/microsoft.authorization/roledefinitions/00000000-0000-0000-0000-000000000007"
    error_message = "A role name that only exists at the resource group must resolve to that role definition id on the host assignment."
  }

  assert {
    condition     = azapi_resource.role_assignments_public_ip["custom"].body.properties.roleDefinitionId == azapi_resource.role_assignments["custom"].body.properties.roleDefinitionId
    error_message = "The public IP assignment must send the same resolved role definition id as the host assignment."
  }
  providers = {
    azapi  = azapi
    modtm  = modtm
    random = random
  }
}

run "sends_service_principal_type_when_skip_check_is_true" {
  command = apply

  variables {
    role_assignments = {
      skip = {
        role_definition_id_or_name       = "Reader"
        principal_id                     = "00000000-0000-0000-0000-000000000004"
        skip_service_principal_aad_check = true
      }
      explicit = {
        role_definition_id_or_name       = "Reader"
        principal_id                     = "00000000-0000-0000-0000-000000000005"
        skip_service_principal_aad_check = true
        principal_type                   = "Group"
      }
      default = {
        role_definition_id_or_name = "Reader"
        principal_id               = "00000000-0000-0000-0000-000000000006"
      }
    }
  }

  assert {
    condition     = azapi_resource.role_assignments["skip"].body.properties.principalType == "ServicePrincipal"
    error_message = "skip_service_principal_aad_check = true must send principalType ServicePrincipal when principal_type is unset."
  }

  assert {
    condition     = azapi_resource.role_assignments["explicit"].body.properties.principalType == "Group"
    error_message = "An explicit principal_type must win over skip_service_principal_aad_check."
  }

  assert {
    condition     = azapi_resource.role_assignments["default"].body.properties.principalType == null
    error_message = "principalType must stay unset when neither the flag nor principal_type is set."
  }

  assert {
    condition     = azapi_resource.role_assignments_public_ip["skip"].body.properties.principalType == "ServicePrincipal"
    error_message = "The public IP assignment must also send principalType ServicePrincipal when the flag is true."
  }

  assert {
    condition     = azapi_resource.role_assignments_public_ip["explicit"].body.properties.principalType == "Group"
    error_message = "An explicit principal_type must win on the public IP assignment too."
  }

  assert {
    condition     = azapi_resource.role_assignments_public_ip["default"].body.properties.principalType == null
    error_message = "principalType must stay unset on the public IP assignment when neither the flag nor principal_type is set."
  }
  providers = {
    azapi  = azapi
    modtm  = modtm
    random = random
  }
}

run "derives_distinct_lowercase_names" {
  command = apply

  variables {
    role_assignments = {
      first = {
        role_definition_id_or_name = "Reader"
        principal_id               = "00000000-0000-0000-0000-00000000000A"
      }
      second = {
        role_definition_id_or_name = "Reader"
        principal_id               = "00000000-0000-0000-0000-00000000000b"
      }
    }
  }

  assert {
    condition     = azapi_resource.role_assignments["first"].name != azapi_resource.role_assignments["second"].name
    error_message = "Assignments with different principals must get different derived names."
  }

  assert {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$", azapi_resource.role_assignments["first"].name))
    error_message = "A derived role assignment name must be a lowercase UUIDv5."
  }

  assert {
    condition     = azapi_resource.role_assignments["first"].body.properties.principalId == "00000000-0000-0000-0000-00000000000a"
    error_message = "The principal id must be lowercased in the request body."
  }

  assert {
    condition     = azapi_resource.role_assignments_public_ip["first"].name != azapi_resource.role_assignments["first"].name
    error_message = "The public IP copy must not reuse the host assignment name."
  }

  assert {
    condition     = azapi_resource.role_assignments_public_ip["first"].name != azapi_resource.role_assignments_public_ip["second"].name
    error_message = "Public IP assignments with different principals must get different derived names."
  }
  providers = {
    azapi  = azapi
    modtm  = modtm
    random = random
  }
}

run "pinned_name_is_kept_on_the_host_and_distinct_on_the_public_ip" {
  command = apply

  variables {
    role_assignments = {
      pinned = {
        name                       = "11111111-1111-4111-8111-111111111111"
        role_definition_id_or_name = "Reader"
        principal_id               = "00000000-0000-0000-0000-000000000004"
      }
    }
  }

  assert {
    condition     = azapi_resource.role_assignments["pinned"].name == "11111111-1111-4111-8111-111111111111"
    error_message = "A pinned name must be used for the host assignment."
  }

  assert {
    condition     = azapi_resource.role_assignments_public_ip["pinned"].name != azapi_resource.role_assignments["pinned"].name
    error_message = "A pinned name must not be reused at the public IP scope."
  }

  assert {
    condition = azapi_resource.role_assignments_public_ip["pinned"].name == uuidv5("url", join("|", [
      "11111111-1111-4111-8111-111111111111",
      lower(module.public_ip_address[0].resource_id),
    ]))
    error_message = "The public IP copy of a pinned name must be derived from the pinned name and the public IP id."
  }

  assert {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$", azapi_resource.role_assignments_public_ip["pinned"].name))
    error_message = "The derived public IP name must be a lowercase UUIDv5."
  }
  providers = {
    azapi  = azapi
    modtm  = modtm
    random = random
  }
}

run "retries_principal_not_found_on_role_assignments_by_default" {
  command = apply

  assert {
    condition     = contains(azapi_resource.role_assignments["custom"].retry.error_message_regex, "PrincipalNotFound") && contains(azapi_resource.role_assignments["custom"].retry.error_message_regex, "ReferencedResourceNotProvisioned")
    error_message = "The default retry must cover PrincipalNotFound and keep ReferencedResourceNotProvisioned on the host role assignment."
  }

  assert {
    condition     = contains(azapi_resource.role_assignments_public_ip["custom"].retry.error_message_regex, "PrincipalNotFound")
    error_message = "The default retry must cover PrincipalNotFound on the public IP role assignment."
  }
  providers = {
    azapi  = azapi
    modtm  = modtm
    random = random
  }
}

run "forwards_custom_retry_to_role_assignments" {
  command = apply

  variables {
    retry = {
      error_message_regex = ["CustomTransient"]
      interval_seconds    = 7
    }
  }

  assert {
    condition     = azapi_resource.role_assignments["custom"].retry.error_message_regex == tolist(["CustomTransient"]) && azapi_resource.role_assignments["custom"].retry.interval_seconds == 7
    error_message = "A consumer retry override must reach the host role assignment."
  }

  assert {
    condition     = azapi_resource.role_assignments_public_ip["custom"].retry.error_message_regex == tolist(["CustomTransient"])
    error_message = "A consumer retry override must reach the public IP role assignment."
  }
  providers = {
    azapi  = azapi
    modtm  = modtm
    random = random
  }
}
