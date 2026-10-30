locals {
  # Role names resolve at the resource group of the Bastion host and its owned public IP.
  role_assignment_definition_scope = var.parent_id

  # Role assignment request bodies, one set per scope. The ids are lowercased so a casing-only
  # change does not replace an assignment. AzureRM sent `principalType = "ServicePrincipal"`
  # when `skip_service_principal_aad_check` was true; an explicit `principal_type` wins.
  role_assignment_properties = {
    for key, assignment in module.interfaces.role_assignments_azapi : key => merge(
      assignment.body.properties,
      {
        principalId      = lower(assignment.body.properties.principalId)
        roleDefinitionId = lower(assignment.body.properties.roleDefinitionId)
      },
      assignment.body.properties.delegatedManagedIdentityResourceId == null ? {} : {
        delegatedManagedIdentityResourceId = lower(assignment.body.properties.delegatedManagedIdentityResourceId)
      },
      var.role_assignments[key].skip_service_principal_aad_check && var.role_assignments[key].principal_type == null ? {
        principalType = "ServicePrincipal"
      } : {},
    )
  }
  role_assignment_properties_public_ip = {
    for key, assignment in module.interfaces_public_ip.role_assignments_azapi : key => merge(
      assignment.body.properties,
      {
        principalId      = lower(assignment.body.properties.principalId)
        roleDefinitionId = lower(assignment.body.properties.roleDefinitionId)
      },
      assignment.body.properties.delegatedManagedIdentityResourceId == null ? {} : {
        delegatedManagedIdentityResourceId = lower(assignment.body.properties.delegatedManagedIdentityResourceId)
      },
      var.role_assignments[key].skip_service_principal_aad_check && var.role_assignments[key].principal_type == null ? {
        principalType = "ServicePrincipal"
      } : {},
    )
  }
}

locals {
  # The Bastion host address, whichever of the two mutually exclusive writers exists.
  bastion_resource_id = var.sku == "Developer" ? azapi_resource.bastion_developer[0].id : azapi_resource.bastion[0].id

  # `avm-utl-interfaces` builds the lock body without `notes`. AzureRM always set them, so
  # they are merged back in to avoid clearing the notes of an existing lock on upgrade.
  # `var.lock.notes` wins over these defaults.
  lock_notes = var.lock == null ? null : coalesce(
    var.lock.notes,
    var.lock.kind == "CanNotDelete"
    ? "Cannot delete the resource or its child resources."
    : "Cannot delete or modify the resource or its child resources."
  )

  # The utility module's `lock` type has no `notes`, so it is dropped here. `local.lock_notes` writes it.
  lock_utl = var.lock == null ? null : {
    kind = var.lock.kind
    name = var.lock.name
  }
}

locals {
  # `var.timeouts` may be null, `{}` or partial. The null is absorbed once here.
  timeouts_input = var.timeouts != null ? var.timeouts : {
    create = null
    read   = null
    update = null
    delete = null
  }
}

locals {
  # Per-resource fallbacks to the AzureRM defaults of the resources replaced, so a migrated
  # deployment keeps its timeouts. Locks and role assignments had no update timeout in
  # AzureRM, so the create value is reused.
  timeouts = {
    network_bastion_hosts = {
      create = local.timeouts_input.create != null ? local.timeouts_input.create : "30m"
      read   = local.timeouts_input.read != null ? local.timeouts_input.read : "5m"
      update = local.timeouts_input.update != null ? local.timeouts_input.update : "30m"
      delete = local.timeouts_input.delete != null ? local.timeouts_input.delete : "30m"
    }
    authorization_locks = {
      create = local.timeouts_input.create != null ? local.timeouts_input.create : "30m"
      read   = local.timeouts_input.read != null ? local.timeouts_input.read : "5m"
      update = local.timeouts_input.update != null ? local.timeouts_input.update : "30m"
      delete = local.timeouts_input.delete != null ? local.timeouts_input.delete : "30m"
    }
    authorization_role_assignments = {
      create = local.timeouts_input.create != null ? local.timeouts_input.create : "30m"
      read   = local.timeouts_input.read != null ? local.timeouts_input.read : "5m"
      update = local.timeouts_input.update != null ? local.timeouts_input.update : "30m"
      delete = local.timeouts_input.delete != null ? local.timeouts_input.delete : "30m"
    }
    # AzureRM deleted diagnostic settings with a 60m timeout, not 30m.
    insights_diagnostic_settings = {
      create = local.timeouts_input.create != null ? local.timeouts_input.create : "30m"
      read   = local.timeouts_input.read != null ? local.timeouts_input.read : "5m"
      update = local.timeouts_input.update != null ? local.timeouts_input.update : "30m"
      delete = local.timeouts_input.delete != null ? local.timeouts_input.delete : "60m"
    }
  }

  # `azapi_resource` distinguishes `[]` from `null`; only `null` means "ignore nothing".
  ignore_body_changes = {
    for key, paths in var.ignore_body_changes : key => length(paths) > 0 ? paths : null
    if key != "public_ip_address"
  }
}

locals {
  public_ip_resource_id = length(module.public_ip_address) == 0 ? (length(data.azapi_resource.public_ip) == 0 ? null : { id = data.azapi_resource.public_ip[0].id }) : { id = module.public_ip_address[0].resource_id }

  # Zones of the public IP for the precondition on the Bastion writer. AzAPI returns the raw
  # ARM member: `tostring` makes it comparable to `var.zones`, and `try` covers a public IP
  # with no zones (the member is omitted) and an unread data source, as AzureRM did.
  public_ip_zone_config = length(module.public_ip_address) == 0 ? (
    length(data.azapi_resource.public_ip) == 0 ? [] : try([for zone in data.azapi_resource.public_ip[0].output.zones : tostring(zone)], [])
  ) : var.zones
}
