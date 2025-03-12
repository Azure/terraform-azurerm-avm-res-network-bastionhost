resource "azurerm_bastion_host" "this" {
  location                  = var.location
  name                      = var.name
  resource_group_name       = var.resource_group_name
  copy_paste_enabled        = var.copy_paste_enabled
  file_copy_enabled         = var.file_copy_enabled
  ip_connect_enabled        = var.ip_connect_enabled
  kerberos_enabled          = var.kerberos_enabled
  scale_units               = var.scale_units
  session_recording_enabled = var.session_recording_enabled
  shareable_link_enabled    = var.shareable_link_enabled
  sku                       = var.sku
  tags                      = var.tags
  tunneling_enabled         = var.tunneling_enabled
  virtual_network_id        = var.virtual_network_id
  zones                     = var.zones

  dynamic "ip_configuration" {
    for_each = var.ip_configuration != null ? [var.ip_configuration] : []

    content {
      name                 = coalesce(var.ip_configuration.name, "ipconfig-${var.name}")
      public_ip_address_id = local.public_ip_resource_id
      subnet_id            = var.ip_configuration.subnet_id
    }
  }

  lifecycle {
    precondition {
      condition     = length(local.public_ip_zone_config) == length(var.zones)
      error_message = "The number of zones in the public IP address must match the number of zones in the Azure Bastion Host."
    }
  }
}

resource "azurerm_management_lock" "this" {
  count = var.lock != null ? 1 : 0

  lock_level = var.lock.kind
  name       = coalesce(var.lock.name, "lock-${var.lock.kind}")
  scope      = azurerm_bastion_host.this.id
  notes      = var.lock.kind == "CanNotDelete" ? "Cannot delete the resource or its child resources." : "Cannot delete or modify the resource or its child resources."
}


resource "azurerm_monitor_diagnostic_setting" "this" {
  for_each = var.diagnostic_settings

  name                           = each.value.name != null ? each.value.name : "diag-${var.name}"
  target_resource_id             = azurerm_bastion_host.this.id
  eventhub_authorization_rule_id = each.value.event_hub_authorization_rule_resource_id
  eventhub_name                  = each.value.event_hub_name
  log_analytics_destination_type = each.value.log_analytics_destination_type
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
  count               = var.ip_configuration != null ? (var.ip_configuration.create_public_ip == true ? 1 : 0) : var.sku == "Developer" ? 0 :1
  source              = "Azure/avm-res-network-publicipaddress/azurerm"
  version             = "0.2.0"
  enable_telemetry    = var.enable_telemetry
  resource_group_name = var.resource_group_name
  name                = "pip-${var.name}"
  location            = var.location
  sku                 = "Standard"
  zones               = var.zones
}

resource "azurerm_management_lock" "pip" {
  count = var.lock != null && length(module.public_ip_address) > 0 ? 1 : 0

  lock_level = var.lock.kind
  name       = coalesce(var.lock.name, "lock-${var.lock.kind}-pip")
  scope      = module.public_ip_address[0].resource_id
  notes      = var.lock.kind == "CanNotDelete" ? "Cannot delete the resource or its child resources." : "Cannot delete or modify the resource or its child resources."
}

data "azurerm_public_ip" "this" {
  count = var.ip_configuration != null ? (var.ip_configuration.create_public_ip == false ? 1 : 0) : 0

  name                = split("/", var.ip_configuration.public_ip_address_id)[length(split("/", var.ip_configuration.public_ip_address_id)) - 1]
  resource_group_name = split("/", var.ip_configuration.public_ip_address_id)[4]
}

resource "azurerm_role_assignment" "this" {
  for_each = var.role_assignments

  principal_id                           = each.value.principal_id
  scope                                  = azurerm_bastion_host.this.id
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