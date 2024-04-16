resource "azurerm_bastion_host" "bastion" {
  name                = var.bastion_host.name
  resource_group_name = var.bastion_host.resource_group_name
  location            = var.bastion_host.location
  sku                 = var.bastion_host.sku
  ip_configuration {
    name                 = var.bastion_host.ip_configuration.name
    subnet_id            = var.bastion_host.ip_configuration.subnet_id
    public_ip_address_id = var.bastion_host.ip_configuration.public_ip_address_id
  }

  # Conditional arguments based on SKU value
  copy_paste_enabled     = var.bastion_host.sku == "Standard" ? var.bastion_host.copy_paste_enabled : null
  file_copy_enabled      = var.bastion_host.sku == "Standard" ? var.bastion_host.file_copy_enabled : null
  ip_connect_enabled     = var.bastion_host.sku == "Standard" ? var.bastion_host.ip_connect_enabled : null
  scale_units            = var.bastion_host.sku == "Standard" ? var.bastion_host.scale_units : null
  shareable_link_enabled = var.bastion_host.sku == "Standard" ? var.bastion_host.shareable_link_enabled : null
  tunneling_enabled      = var.bastion_host.sku == "Standard" ? var.bastion_host.tunneling_enabled : null

  tags = var.tags
}


# AVM Required Interfaces

resource "azurerm_management_lock" "this" {
  count      = var.lock.kind != "None" ? 1 : 0
  name       = coalesce(var.lock.name, "lock-${var.bastion_host.name}")
  scope      = azurerm_bastion_host.bastion.id
  lock_level = var.lock.kind
}

# Diagnostic Settings

resource "azurerm_monitor_diagnostic_setting" "this" {
  for_each = var.diagnostic_settings

  name                           = each.value.name != null ? each.value.name : "diag-${var.bastion_host.name}"
  target_resource_id             = azurerm_bastion_host.bastion.id
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

# Role Assignments
resource "azurerm_role_assignment" "this" {
  for_each = var.role_assignments

  principal_id                           = each.value.principal_id
  scope                                  = azurerm_bastion_host.bastion.id
  condition                              = each.value.condition
  condition_version                      = each.value.condition_version
  delegated_managed_identity_resource_id = each.value.delegated_managed_identity_resource_id
  role_definition_id                     = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? each.value.role_definition_id_or_name : null
  role_definition_name                   = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? null : each.value.role_definition_id_or_name
  skip_service_principal_aad_check       = each.value.skip_service_principal_aad_check
}
