
resource "azapi_resource" "bastion" {
  count = var.sku == "Developer" ? 0 : 1

  type = "Microsoft.Network/bastionHosts@2024-05-01"
  body = {
    sku = {
      name = var.sku
    }
    zones = var.zones
    properties = {
      disableCopyPaste         = !var.copy_paste_enabled
      enableFileCopy           = var.file_copy_enabled
      enableIpConnect          = var.ip_connect_enabled
      enableKerberos           = var.kerberos_enabled
      enablePrivateOnlyBastion = var.private_only_enabled
      enableSessionRecording   = var.session_recording_enabled
      enableShareableLink      = var.shareable_link_enabled
      enableTunneling          = var.tunneling_enabled
      ipConfigurations = [
        {
          name = coalesce(var.ip_configuration.name, "ipconfig-${var.name}")
          properties = {
            privateIPAllocationMethod = "Dynamic"
            publicIPAddress           = local.public_ip_resource_id
            subnet = {
              id = var.ip_configuration.subnet_id
            }
          }
        }
      ]
      scaleUnits = var.scale_units
    }
  }
  location  = var.location
  name      = var.name
  parent_id = local.resource_group_id
  replace_triggers_external_values = [
    var.sku
  ]
  response_export_values = ["properties.dnsName"]
  tags                   = var.tags

  lifecycle {
    precondition {
      condition     = var.private_only_enabled != true ? sort(local.public_ip_zone_config) == sort(var.zones) : true
      error_message = "The number of zones in the public IP address must match the number of zones in the Azure Bastion Host."
    }
  }
}

resource "azapi_resource" "bastion_developer" {
  count = var.sku == "Developer" ? 1 : 0

  type = "Microsoft.Network/bastionHosts@2024-05-01"
  body = {
    sku = {
      name = var.sku
    }
    properties = {
      virtualNetwork = {
        id = var.virtual_network_id
      }
    }
  }
  location               = var.location
  name                   = var.name
  parent_id              = local.resource_group_id
  response_export_values = ["properties.dnsName"]
  tags                   = var.tags
}

resource "azurerm_management_lock" "this" {
  count = var.lock != null ? 1 : 0

  lock_level = var.lock.kind
  name       = coalesce(var.lock.name, "lock-${var.lock.kind}")
  scope      = var.sku == "Developer" ? azapi_resource.bastion_developer[0].id : azapi_resource.bastion[0].id
  notes      = var.lock.kind == "CanNotDelete" ? "Cannot delete the resource or its child resources." : "Cannot delete or modify the resource or its child resources."
}


resource "azurerm_monitor_diagnostic_setting" "this" {
  for_each = var.diagnostic_settings

  name                           = each.value.name != null ? each.value.name : "diag-${var.name}"
  target_resource_id             = var.sku == "Developer" ? azapi_resource.bastion_developer[0].id : azapi_resource.bastion[0].id
  eventhub_authorization_rule_id = each.value.event_hub_authorization_rule_resource_id
  eventhub_name                  = each.value.event_hub_name
  log_analytics_workspace_id     = each.value.workspace_resource_id
  partner_solution_id            = each.value.marketplace_partner_resource_id
  storage_account_id             = each.value.storage_account_resource_id

  dynamic "enabled_log" {
    for_each = each.value.log_categories

    content {
      category = enabled_log.value
    }
  }
  dynamic "enabled_log" {
    for_each = each.value.log_groups

    content {
      category_group = enabled_log.value
    }
  }
  dynamic "metric" {
    for_each = each.value.metric_categories

    content {
      category = metric.value
    }
  }
}


module "public_ip_address" {
  count               = var.ip_configuration != null ? (var.ip_configuration.create_public_ip == true ? 1 : 0) : var.sku == "Developer" ? 0 : 1
  source              = "Azure/avm-res-network-publicipaddress/azurerm"
  version             = "0.2.0"
  enable_telemetry    = var.enable_telemetry
  resource_group_name = var.resource_group_name
  name                = coalesce(var.ip_configuration.public_ip_address_name, "pip-${var.name}")
  location            = var.location
  sku                 = "Standard"
  zones               = var.zones
  tags                = var.tags
}

resource "azurerm_management_lock" "pip" {
  count = var.lock != null && length(module.public_ip_address) > 0 ? 1 : 0

  lock_level = var.lock.kind
  name       = coalesce(var.lock.name, "lock-${var.lock.kind}-pip")
  scope      = module.public_ip_address[0].resource_id
  notes      = var.lock.kind == "CanNotDelete" ? "Cannot delete the resource or its child resources." : "Cannot delete or modify the resource or its child resources."
}

data "azurerm_public_ip" "this" {
  count = var.ip_configuration != null ? (var.ip_configuration.create_public_ip == false && var.private_only_enabled == false ? 1 : 0) : 0

  name                = split("/", var.ip_configuration.public_ip_address_id)[length(split("/", var.ip_configuration.public_ip_address_id)) - 1]
  resource_group_name = split("/", var.ip_configuration.public_ip_address_id)[4]
}

resource "azurerm_role_assignment" "this" {
  for_each = var.role_assignments

  principal_id                           = each.value.principal_id
  scope                                  = var.sku == "Developer" ? azapi_resource.bastion_developer[0].id : azapi_resource.bastion[0].id
  condition                              = each.value.condition
  condition_version                      = each.value.condition_version
  delegated_managed_identity_resource_id = each.value.delegated_managed_identity_resource_id
  principal_type                         = each.value.principal_type
  role_definition_id                     = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? each.value.role_definition_id_or_name : null
  role_definition_name                   = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? null : each.value.role_definition_id_or_name
  skip_service_principal_aad_check       = each.value.skip_service_principal_aad_check
}

resource "azurerm_role_assignment" "pip" {
  for_each = length(module.public_ip_address) > 0 ? var.role_assignments : {}

  principal_id                           = each.value.principal_id
  scope                                  = module.public_ip_address[0].resource_id
  condition                              = each.value.condition
  condition_version                      = each.value.condition_version
  delegated_managed_identity_resource_id = each.value.delegated_managed_identity_resource_id
  principal_type                         = each.value.principal_type
  role_definition_id                     = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? each.value.role_definition_id_or_name : null
  role_definition_name                   = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? null : each.value.role_definition_id_or_name
  skip_service_principal_aad_check       = each.value.skip_service_principal_aad_check
}
