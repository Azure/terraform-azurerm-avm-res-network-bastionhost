# ---------------------------------------------------------------------------
# AzureRM parity references used throughout this module. Every `Lnn`-free
# citation below names the file it was read from in
# `hashicorp/terraform-provider-azurerm` v4.81.0:
#
#   BASTION = internal/services/network/bastion_host_resource.go
#   LOCK    = internal/services/resource/management_lock_resource.go
#   RA      = internal/services/authorization/role_assignment_resource.go
#   DIAG    = internal/services/monitor/monitor_diagnostic_setting_resource.go
#
# Nothing here is inferred from the provider documentation.
# ---------------------------------------------------------------------------

locals {
  # `var.parent_id` is validated as a resource group ID in `variables.tf`, so this parse
  # cannot fail and the members below are checked rather than assumed. Replaces the
  # `split("/", var.parent_id)[4]` / `[2]` index arithmetic the AzureRM-era module used.
  parent_resource_group = provider::azapi::parse_resource_id("Microsoft.Resources/resourceGroups", var.parent_id)

  # Role definitions are looked up at subscription scope, which is where AzureRM's
  # `role_definition_name` resolution effectively pointed: `azurerm_role_assignment`
  # (RA) resolved a role NAME against the subscription of the provider block, and a
  # Bastion host always lives in the same subscription as its resource group.
  role_assignment_definition_scope = "/subscriptions/${local.parent_resource_group.subscription_id}"
}

locals {
  # The Bastion host address, whichever of the two mutually exclusive writers exists.
  # `var.sku` decides which, and exactly one of the two `count`s is 1 for any value.
  bastion_resource_id = var.sku == "Developer" ? azapi_resource.bastion_developer[0].id : azapi_resource.bastion[0].id

  # `Azure/avm-utl-interfaces/azure` 0.6.0 builds `lock_azapi.body` from `var.lock.kind`
  # alone (`locals.lock.tf`: `body = { properties = { level = var.lock.kind } }`) and has
  # no slot for `notes` -- its own `lock` variable is the interface variant 1 shape,
  # `object({ kind, name })`. The AzureRM-era resources DID set `notes`, with the exact
  # strings below, so they are merged back in rather than dropped; otherwise every
  # existing consumer would see the lock's notes cleared on upgrade.
  #
  # `var.lock.notes` is the variant 2 attribute this module accepts but the utility
  # module cannot carry, so it is applied here and takes precedence over the parity
  # default. It is NOT passed to the utility module -- see `local.lock_utl` below.
  lock_notes = var.lock == null ? null : coalesce(
    var.lock.notes,
    var.lock.kind == "CanNotDelete"
    ? "Cannot delete the resource or its child resources."
    : "Cannot delete or modify the resource or its child resources."
  )

  # The trimmed object handed to both `avm-utl-interfaces` calls. That module pins its
  # `lock` variable to `object({ kind = string, name = optional(string, null) })`, so
  # passing `var.lock` straight through would fail type conversion the moment this
  # module's variant 2 `notes` attribute is present. Dropping `notes` here is lossless
  # because `local.lock_notes` above is what actually writes it.
  lock_utl = var.lock == null ? null : {
    kind = var.lock.kind
    name = var.lock.name
  }
}

locals {
  # TFFR7 forbids `nullable = false` on `var.timeouts` (`avm_interface_timeouts`), so the
  # variable accepts an explicit `null` as well as `{}` and a partially-populated object.
  # All three mean the same thing -- "fall back" -- and the null is absorbed once, here,
  # rather than in each of the sixteen expressions below.
  timeouts_input = var.timeouts != null ? var.timeouts : {
    create = null
    read   = null
    update = null
    delete = null
  }
}

locals {
  # Per-resource timeout fallbacks.
  #
  # `var.timeouts` is the flat four-attribute TFFR7 object, because that is the shape a
  # parent module cascades through unchanged. It carries no inline defaults; each
  # attribute is null when unset and falls back HERE, per resource, to the AzureRM default
  # of the resource it replaced, so a migrated deployment keeps the timeouts it had.
  timeouts = {
    # azapi_resource.bastion / azapi_resource.bastion_developer -> azurerm_bastion_host
    #   BASTION: Create 30m, Read 5m, Update 30m, Delete 30m.
    network_bastion_hosts = {
      create = local.timeouts_input.create != null ? local.timeouts_input.create : "30m"
      read   = local.timeouts_input.read != null ? local.timeouts_input.read : "5m"
      update = local.timeouts_input.update != null ? local.timeouts_input.update : "30m"
      delete = local.timeouts_input.delete != null ? local.timeouts_input.delete : "30m"
    }
    # azapi_resource.lock / azapi_resource.lock_public_ip -> azurerm_management_lock
    #   LOCK: Create 30m, Read 5m, Delete 30m -- and NO Update timeout, because every
    #   attribute on that resource is ForceNew and it has no Update function at all. The
    #   AzAPI resource does have an update path, so the create value is reused for it.
    authorization_locks = {
      create = local.timeouts_input.create != null ? local.timeouts_input.create : "30m"
      read   = local.timeouts_input.read != null ? local.timeouts_input.read : "5m"
      update = local.timeouts_input.update != null ? local.timeouts_input.update : "30m"
      delete = local.timeouts_input.delete != null ? local.timeouts_input.delete : "30m"
    }
    # azapi_resource.role_assignments / .role_assignments_public_ip -> azurerm_role_assignment
    #   RA: Create 30m, Read 5m, Delete 30m -- again no Update timeout and no Update
    #   function. Same reasoning as the locks.
    authorization_role_assignments = {
      create = local.timeouts_input.create != null ? local.timeouts_input.create : "30m"
      read   = local.timeouts_input.read != null ? local.timeouts_input.read : "5m"
      update = local.timeouts_input.update != null ? local.timeouts_input.update : "30m"
      delete = local.timeouts_input.delete != null ? local.timeouts_input.delete : "30m"
    }
    # azapi_resource.diagnostic_settings -> azurerm_monitor_diagnostic_setting
    #   DIAG: Create 30m, Read 5m, Update 30m, Delete 60m.
    #   🔴 The delete is 60m, NOT the Bastion host's 30m. This asymmetry is the whole
    #   reason the fallbacks are per resource rather than one shared object.
    insights_diagnostic_settings = {
      create = local.timeouts_input.create != null ? local.timeouts_input.create : "30m"
      read   = local.timeouts_input.read != null ? local.timeouts_input.read : "5m"
      update = local.timeouts_input.update != null ? local.timeouts_input.update : "30m"
      delete = local.timeouts_input.delete != null ? local.timeouts_input.delete : "60m"
    }
  }

  # TFFR8: `azapi_resource` distinguishes `[]` from `null`, and only `null` means "ignore
  # nothing". An empty list would be a non-null value that the provider then has to
  # reconcile, so every list is collapsed at the boundary instead of at each use site.
  ignore_body_changes = {
    for key, paths in var.ignore_body_changes : key => length(paths) > 0 ? paths : null
    if key != "public_ip_address"
  }
}

# LOCALS Description:
# public_ip_resource_id: This is the resource ID of the public IP resource to be associated with the Azure Bastion Host. This depends on whether a public IP was provided or not.
# public_ip_zone_config: The zone configuration of the public IP address. We use this to ensure the configuration matches the Azure Bastion Host.
locals {
  public_ip_resource_id = length(module.public_ip_address) == 0 ? (length(data.azapi_resource.public_ip) == 0 ? null : { id = data.azapi_resource.public_ip[0].id }) : { id = module.public_ip_address[0].resource_id }

  # Feeds the `lifecycle.precondition` on the Bastion writer, which compares the public
  # IP's zones against the Bastion host's.
  #
  # AzureRM exposed `data.azurerm_public_ip.this.zones` as a `[]string` it had already
  # flattened. AzAPI returns the raw ARM member, so the shape is restored explicitly:
  #   - `tostring` per element, because ARM's `zones` is an array of strings but the
  #     dynamic value would otherwise compare unequal to `var.zones` (a `set(string)`)
  #     purely on type;
  #   - `try(..., [])` because `.output` is unknown until the data source has been read
  #     once, and because a public IP with no zones omits the member entirely rather than
  #     returning `[]`. AzureRM's flattener produced an empty slice in exactly that case,
  #     so the fallback is parity and not a new behaviour.
  public_ip_zone_config = length(module.public_ip_address) == 0 ? (
    length(data.azapi_resource.public_ip) == 0 ? [] : try([for zone in data.azapi_resource.public_ip[0].output.zones : tostring(zone)], [])
  ) : var.zones
}
