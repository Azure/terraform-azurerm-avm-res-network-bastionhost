# =============================================================================
# SHARED AVM INTERFACES: lock, role assignments, diagnostic settings.
#
# Composed through `Azure/avm-utl-interfaces/azure ~> 0.6`, which turns the
# standard AVM variable shapes into `{ type, name, body }` triples ready for
# `azapi_resource`. That is the AVM target for interfaces and it removes the
# last `azurerm_*` resource blocks from this module.
#
# 🔴 WHY THERE ARE TWO CALLS AND NOT ONE. `avm-utl-interfaces` keeps one set of
# role-assignment bodies per call. The Bastion host and the public IP are separate
# scopes with their own assignments, so each scope has its own call, which also
# preserves the AzureRM-era `azurerm_role_assignment.this` and `.pip` arrangement.
# The resources below do not use the utility module's `random_uuid` names; they derive
# their own so an explicit `name` is never reused across the two scopes.
#
# The state moves for every resource in this file are at the bottom.
# =============================================================================

module "interfaces" {
  source  = "Azure/avm-utl-interfaces/azure"
  version = "0.6.0"

  diagnostic_settings = var.diagnostic_settings
  enable_telemetry    = var.enable_telemetry
  # `local.lock_utl`, not `var.lock`. This module's `lock` is the AVM interface variant 2
  # shape (`kind`/`name`/`notes`); the utility module's is still variant 1
  # (`object({ kind, name })`), so the `notes` attribute is trimmed at the boundary and
  # written by `local.lock_notes` below instead. See `locals.tf`.
  lock                             = local.lock_utl
  role_assignment_definition_scope = local.role_assignment_definition_scope
  role_assignments                 = var.role_assignments
}

module "interfaces_public_ip" {
  source  = "Azure/avm-utl-interfaces/azure"
  version = "0.6.0"

  # The AzureRM-era module never created diagnostic settings on the public IP, only a
  # lock and role assignments. That surface is preserved exactly.
  diagnostic_settings = {}
  # Deliberately FALSE. This is the second call inside a single invocation of this
  # module; leaving it on would emit two `modtm_telemetry` records for one Bastion
  # host and double-count the module in AVM usage telemetry. The call above carries
  # the consumer's setting.
  enable_telemetry                 = false
  lock                             = local.lock_utl
  role_assignment_definition_scope = local.role_assignment_definition_scope
  # Gated so that neither the per-key `random_uuid` resources nor the role definition
  # lookup are instantiated when this module is not creating a public IP. Mirrors the
  # `for_each` guard AzureRM-era `azurerm_role_assignment.pip` carried.
  role_assignments = length(module.public_ip_address) > 0 ? var.role_assignments : {}
}

# Management lock on the Azure Bastion Host.
resource "azapi_resource" "lock" {
  count = var.lock != null ? 1 : 0

  name      = coalesce(module.interfaces.lock_azapi.name, "lock-${var.lock.kind}")
  parent_id = local.bastion_resource_id
  type      = var.resource_types.authorization_locks
  # `avm-utl-interfaces` 0.6.0 emits only `properties.level`; `local.lock_notes` merges
  # back the `notes` string the AzureRM-era resource set, so an existing lock does not
  # have its notes cleared on upgrade. See `locals.tf`.
  body = {
    properties = {
      level = module.interfaces.lock_azapi.body.properties.level
      notes = local.lock_notes
    }
  }
  ignore_body_changes = local.ignore_body_changes.authorization_locks
  # TFFR4. Empty because nothing reads the lock's response: `outputs.tf` publishes no
  # lock attribute. No `lifecycle.ignore_changes` companion is needed -- that idiom
  # belongs to create-only writers, and this is a plain full writer whose update PUTs
  # `plan.Body` rather than a pinned `state.body` (measured at azapi 2.13.0,
  # `azapi_resource.go` `CreateUpdate`: `unmarshalBody(plan.Body, &body)`).
  response_export_values = []
  retry                  = var.retry

  timeouts {
    create = local.timeouts.authorization_locks.create
    delete = local.timeouts.authorization_locks.delete
    read   = local.timeouts.authorization_locks.read
    update = local.timeouts.authorization_locks.update
  }

  # ⚠️ ORDERING, not decoration. A `ReadOnly` lock on the Bastion host blocks the
  # creation of child resources underneath it, and both resources below ARE children
  # of it by `parent_id`. AzureRM got away without this because the lock's `scope`
  # produced the same single edge to the Bastion host that the diagnostic settings and
  # role assignments had, leaving their relative order to chance. Making it explicit
  # also fixes the destroy order: the lock goes first. No cycle -- everything here
  # already depends on `azapi_resource.bastion`/`.developer`.
  depends_on = [
    azapi_resource.diagnostic_settings,
    azapi_resource.role_assignments,
  ]
}

# Management lock on the public IP address this module created, if it created one.
resource "azapi_resource" "lock_public_ip" {
  count = var.lock != null && length(module.public_ip_address) > 0 ? 1 : 0

  # The `-pip` suffix is the AzureRM-era default and is preserved. Note that when a
  # consumer sets `lock.name` explicitly BOTH locks take that same name, exactly as
  # before; they sit at different scopes, so ARM accepts it.
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

  # A pinned name wins. Otherwise derive one from the host, principal, role and delegated
  # identity, so a replacement caused by a changed principal or role gets a new GUID.
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
  # Keeps the configured casing after refresh, so Azure's casing cannot trigger a replacement.
  ignore_body_changes  = local.ignore_body_changes.authorization_role_assignments
  ignore_casing        = true
  ignore_null_property = true
  # ARM rejects an in-place change of these members (`RoleAssignmentUpdateNotPermitted`), so a
  # change replaces the assignment. A replacement takes the configured name, which is a new
  # derived GUID unless the consumer pinned `name`.
  replace_triggers_refs = [
    "properties.principalId",
    "properties.roleDefinitionId",
    "properties.delegatedManagedIdentityResourceId",
  ]
  # TFFR4. Empty: nothing reads a role assignment's response.
  response_export_values = []
  retry                  = var.retry

  timeouts {
    create = local.timeouts.authorization_role_assignments.create
    delete = local.timeouts.authorization_role_assignments.delete
    read   = local.timeouts.authorization_role_assignments.read
    update = local.timeouts.authorization_role_assignments.update
  }

  # A role assignment created by AzureRM has a server-assigned GUID as its name. The state
  # move recovers it from the resource id, while the derived name above can never match it,
  # and `name` carries `RequiresReplace` in AzAPI. Without this the first plan after upgrading
  # would replace every assignment. `ignore_changes` is inert at create and replace time, so a
  # new or replaced assignment takes the configured name.
  lifecycle {
    ignore_changes = [name]
  }
}

# Role assignments scoped to the public IP address this module created.
resource "azapi_resource" "role_assignments_public_ip" {
  for_each = module.interfaces_public_ip.role_assignments_azapi

  # Role assignment names must be unique across scopes, so the public IP copy never reuses the
  # host's name. With a pinned name the copy is derived from that name and the public IP.
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
  # MEASURED perpetual diff, and the fix for it.
  #
  # `Microsoft.Network/bastionHosts` exposes TWO log category groups, `allLogs` and
  # `audit`. `avm-utl-interfaces` emits only the ENABLED entry, so the module PUTs
  # `logs = [{ categoryGroup = "allLogs", enabled = true }]`. ARM stores that, but
  # every subsequent GET returns BOTH groups -- the unrequested one as
  # `{ categoryGroup = "audit", enabled = false }`. At the provider defaults azapi
  # compares the two lists element-wise, sees an extra item in the response, and
  # plans to delete it. Applying changes nothing on the service side, so the diff
  # returns on the very next plan: measured as a genuine perpetual diff (apply
  # succeeded, immediate re-plan still reported `0 to add, 1 to change, 0 to destroy`).
  #
  # `ignore_null_property` does NOT cover this. The extra element is not a null
  # property, it is a surplus LIST MEMBER, which is what `ignore_other_items_in_list`
  # exists for. That attribute needs a stable identity for each element, which is what
  # `list_unique_id_property` supplies: `properties.logs` entries are identified by
  # `category, categoryGroup` (a diagnostic setting may use either form) and
  # `properties.metrics` entries by `category` alone. `properties.metrics` gets the
  # same treatment because `AllMetrics` behaves identically when ARM adds a category
  # the module did not request.
  ignore_other_items_in_list = ["properties.logs", "properties.metrics"]
  list_unique_id_property = {
    "properties.logs"    = "category, categoryGroup"
    "properties.metrics" = "category"
  }
  # TFFR4. Empty: nothing reads a diagnostic setting's response.
  response_export_values = []
  retry                  = var.retry
  # `Microsoft.Insights/diagnosticSettings` is an extension resource whose embedded
  # azapi schema does not model every destination combination cleanly. The side-car
  # reference implementation disables validation here for the same reason; ARM remains
  # the authority on the payload.
  schema_validation_enabled = false

  timeouts {
    create = local.timeouts.insights_diagnostic_settings.create
    delete = local.timeouts.insights_diagnostic_settings.delete
    read   = local.timeouts.insights_diagnostic_settings.read
    update = local.timeouts.insights_diagnostic_settings.update
  }
}

# --- Interface state moves ---------------------------------------------------
#
# All five are plain one-to-one moves at the same cardinality boundary with the
# same keys, unchanged since v0.6.0 -- these blocks did not exist upstream at
# any release, so they cover every consumer from v0.6.0 through v0.9.0 in one
# hop. Like the Bastion host's single move in `main.tf`, each is one cross-type
# hop and no chain: a chain cannot cross azurerm -> azapi -> azapi.
#
# Plan with a normal refresh. `terraform plan -refresh=false` hits azapi#1227
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
