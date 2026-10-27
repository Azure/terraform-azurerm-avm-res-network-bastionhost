# Lock, role assignments and diagnostic settings from `Azure/avm-utl-interfaces/azure`.
# There are two calls, one per scope (host and owned public IP), so each scope has its own
# role assignment bodies. The resources below derive their own role assignment names instead
# of using the utility module's `random_uuid`, so a pinned `name` is never reused across scopes.
# The state moves are at the bottom of the file.

module "interfaces" {
  source  = "Azure/avm-utl-interfaces/azure"
  version = "0.9.0"

  location            = var.location
  diagnostic_settings = var.diagnostic_settings
  enable_telemetry    = var.enable_telemetry
  # `local.lock_utl` drops `notes`, which the utility module's `lock` type does not have.
  lock                             = local.lock_utl
  role_assignment_definition_scope = local.role_assignment_definition_scope
  role_assignments                 = var.role_assignments
}

module "interfaces_public_ip" {
  source  = "Azure/avm-utl-interfaces/azure"
  version = "0.9.0"

  location = var.location
  # AzureRM only had a lock and role assignments on the public IP, so there are no diagnostic settings.
  diagnostic_settings = {}
  # False so one Bastion host does not send two telemetry records. The call above carries the setting.
  enable_telemetry                 = false
  lock                             = local.lock_utl
  role_assignment_definition_scope = local.role_assignment_definition_scope
  # Empty when no public IP is created, so no lookup or role assignments are instantiated.
  role_assignments = length(module.public_ip_address) > 0 ? var.role_assignments : {}
}

# Management lock on the Azure Bastion Host.
resource "azapi_resource" "lock" {
  count = var.lock != null ? 1 : 0

  name      = coalesce(module.interfaces.lock_azapi.name, "lock-${var.lock.kind}")
  parent_id = local.bastion_resource_id
  type      = var.resource_types.authorization_locks
  # The utility module emits only `level`; `notes` is merged back, see `locals.tf`.
  body = {
    properties = {
      level = module.interfaces.lock_azapi.body.properties.level
      notes = local.lock_notes
    }
  }
  ignore_body_changes    = local.ignore_body_changes.authorization_locks
  response_export_values = []
  retry                  = var.retry

  timeouts {
    create = local.timeouts.authorization_locks.create
    delete = local.timeouts.authorization_locks.delete
    read   = local.timeouts.authorization_locks.read
    update = local.timeouts.authorization_locks.update
  }

  # A `ReadOnly` lock blocks creating child resources, and both resources below are children
  # of the host. The lock waits for them, and on destroy it goes first.
  depends_on = [
    azapi_resource.diagnostic_settings,
    azapi_resource.role_assignments,
  ]
}

# Management lock on the public IP address this module created, if it created one.
resource "azapi_resource" "lock_public_ip" {
  count = var.lock != null && length(module.public_ip_address) > 0 ? 1 : 0

  # The `-pip` suffix is the AzureRM default. An explicit `lock.name` is used on both
  # locks, as before; they are at different scopes.
  name      = coalesce(module.interfaces_public_ip.lock_azapi.name, "lock-${var.lock.kind}-pip")
  parent_id = module.public_ip_address[0].resource_id
  type      = var.resource_types.authorization_locks
  body = {
    properties = {
      level = module.interfaces_public_ip.lock_azapi.body.properties.level
      notes = local.lock_notes
    }
  }
  ignore_body_changes    = local.ignore_body_changes.authorization_locks
  response_export_values = []
  retry                  = var.retry

  timeouts {
    create = local.timeouts.authorization_locks.create
    delete = local.timeouts.authorization_locks.delete
    read   = local.timeouts.authorization_locks.read
    update = local.timeouts.authorization_locks.update
  }

  depends_on = [
    azapi_resource.role_assignments_public_ip,
  ]
}

# Role assignments scoped to the Azure Bastion Host.
resource "azapi_resource" "role_assignments" {
  for_each = module.interfaces.role_assignments_azapi

  # A pinned name wins. Otherwise the name is derived from the host, principal, role and
  # delegated identity, so a replacement gets a new GUID.
  name = coalesce(
    var.role_assignments[each.key].name,
    uuidv5("url", join("|", [
      lower(local.bastion_resource_id),
      local.role_assignment_properties[each.key].principalId,
      local.role_assignment_properties[each.key].roleDefinitionId,
      lower(coalesce(local.role_assignment_properties[each.key].delegatedManagedIdentityResourceId, "-")),
    ]))
  )
  parent_id = local.bastion_resource_id
  type      = var.resource_types.authorization_role_assignments
  body = {
    properties = local.role_assignment_properties[each.key]
  }
  ignore_body_changes = local.ignore_body_changes.authorization_role_assignments
  # Keeps the configured casing after refresh, so Azure's casing cannot cause a replacement.
  ignore_casing        = true
  ignore_null_property = true
  # ARM rejects an in-place change of these members, so a change replaces the assignment
  # with the configured name: a new derived GUID unless `name` is pinned.
  replace_triggers_refs = [
    "properties.principalId",
    "properties.roleDefinitionId",
    "properties.delegatedManagedIdentityResourceId",
  ]
  response_export_values = []
  retry                  = var.retry

  timeouts {
    create = local.timeouts.authorization_role_assignments.create
    delete = local.timeouts.authorization_role_assignments.delete
    read   = local.timeouts.authorization_role_assignments.read
    update = local.timeouts.authorization_role_assignments.update
  }

  # AzureRM gave an adopted assignment a server-assigned GUID that the derived name cannot
  # match, and `name` forces replacement. Ignoring it keeps the adopted GUID on upgrade.
  # It does not apply at create or replace, which take the configured name.
  lifecycle {
    ignore_changes = [name]
  }
}

# Role assignments scoped to the public IP address this module created.
resource "azapi_resource" "role_assignments_public_ip" {
  for_each = module.interfaces_public_ip.role_assignments_azapi

  # Role assignment names must be unique across scopes, so this never reuses the host's name.
  # With a pinned name, the copy is derived from that name and the public IP.
  name = uuidv5("url", join("|", var.role_assignments[each.key].name == null ? [
    lower(module.public_ip_address[0].resource_id),
    local.role_assignment_properties_public_ip[each.key].principalId,
    local.role_assignment_properties_public_ip[each.key].roleDefinitionId,
    lower(coalesce(local.role_assignment_properties_public_ip[each.key].delegatedManagedIdentityResourceId, "-")),
    ] : [
    var.role_assignments[each.key].name,
    lower(module.public_ip_address[0].resource_id),
  ]))
  parent_id = module.public_ip_address[0].resource_id
  type      = var.resource_types.authorization_role_assignments
  body = {
    properties = local.role_assignment_properties_public_ip[each.key]
  }
  ignore_body_changes  = local.ignore_body_changes.authorization_role_assignments
  ignore_casing        = true
  ignore_null_property = true
  replace_triggers_refs = [
    "properties.principalId",
    "properties.roleDefinitionId",
    "properties.delegatedManagedIdentityResourceId",
  ]
  response_export_values = []
  retry                  = var.retry

  timeouts {
    create = local.timeouts.authorization_role_assignments.create
    delete = local.timeouts.authorization_role_assignments.delete
    read   = local.timeouts.authorization_role_assignments.read
    update = local.timeouts.authorization_role_assignments.update
  }

  lifecycle {
    ignore_changes = [name]
  }
}

# Diagnostic settings on the Azure Bastion Host.
resource "azapi_resource" "diagnostic_settings" {
  for_each = module.interfaces.diagnostic_settings_azapi

  name                 = coalesce(each.value.name, "diag-${var.name}")
  parent_id            = local.bastion_resource_id
  type                 = var.resource_types.insights_diagnostic_settings
  body                 = each.value.body
  ignore_body_changes  = local.ignore_body_changes.insights_diagnostic_settings
  ignore_null_property = true
  # ARM returns both log category groups (`allLogs` and `audit`), but only the enabled one is
  # sent. `ignore_null_property` does not cover that extra list member, so without these two
  # attributes every plan shows a diff that applying does not remove.
  ignore_other_items_in_list = ["properties.logs", "properties.metrics"]
  list_unique_id_property = {
    "properties.logs"    = "category, categoryGroup"
    "properties.metrics" = "category"
  }
  response_export_values = []
  retry                  = var.retry
  # The embedded azapi schema does not model every diagnostic setting destination. ARM validates the payload.
  schema_validation_enabled = false

  timeouts {
    create = local.timeouts.insights_diagnostic_settings.create
    delete = local.timeouts.insights_diagnostic_settings.delete
    read   = local.timeouts.insights_diagnostic_settings.read
    update = local.timeouts.insights_diagnostic_settings.update
  }
}

# State moves for the interfaces. Each is one cross-type hop, as a chain cannot cross
# azurerm to azapi to azapi. Plan with a normal refresh: `-refresh=false` hits azapi#1227
# and reports a replacement instead of a move.

moved {
  from = azurerm_management_lock.this[0]
  to   = azapi_resource.lock[0]
}

moved {
  from = azurerm_management_lock.pip[0]
  to   = azapi_resource.lock_public_ip[0]
}

moved {
  from = azurerm_role_assignment.this
  to   = azapi_resource.role_assignments
}

moved {
  from = azurerm_role_assignment.pip
  to   = azapi_resource.role_assignments_public_ip
}

moved {
  from = azurerm_monitor_diagnostic_setting.this
  to   = azapi_resource.diagnostic_settings
}
