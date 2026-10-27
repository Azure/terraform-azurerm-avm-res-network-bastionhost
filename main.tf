# AzureRM to AzAPI migration in place: same module, same `count` boundary, same
# keys, with `moved` blocks so a consumer only bumps the module version.
#
# Terraform allows one `moved` destination per source address, and a chain cannot
# cross providers. So the Bastion host has exactly one `moved` block (below).
# A deployment created at v0.6.0 or earlier with `sku = "Developer"` cannot be
# moved and is recreated. This is documented in `_header.md`.

# The Bastion host for every SKU except Developer. Exactly one of this resource
# and `azapi_resource.bastion_developer` exists for any value of `var.sku`.
resource "azapi_resource" "bastion" {
  count = var.sku == "Developer" ? 0 : 1

  location  = var.location
  name      = var.name
  parent_id = var.parent_id
  type      = var.resource_types.network_bastion_hosts
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
  ignore_body_changes = local.ignore_body_changes.network_bastion_hosts
  # `sku` is a replace trigger. After a `moved` adoption its state value is null, so the
  # first plan is an in-place update (a full PUT of today's body) and later `sku` changes
  # replace. AzureRM replaced only on a downgrade; this replaces on any change, as v0.7.0 did.
  replace_triggers_external_values = [
    var.sku
  ]
  # Non-empty because `outputs.tf` reads `dns_name`. Do not add `ignore_changes` for it:
  # the adoption update is what fills `.output`.
  response_export_values = ["properties.dnsName"]
  retry                  = var.retry
  tags                   = var.tags

  timeouts {
    create = local.timeouts.network_bastion_hosts.create
    delete = local.timeouts.network_bastion_hosts.delete
    read   = local.timeouts.network_bastion_hosts.read
    update = local.timeouts.network_bastion_hosts.update
  }

  lifecycle {
    precondition {
      condition     = var.private_only_enabled != true ? sort(local.public_ip_zone_config) == sort(var.zones) : true
      error_message = "The number of zones in the public IP address must match the number of zones in the Azure Bastion Host."
    }
  }
}

# The Developer SKU Bastion host. Same ARM type, different writable surface:
# no IP configuration, no zones, no feature flags.
resource "azapi_resource" "bastion_developer" {
  count = var.sku == "Developer" ? 1 : 0

  location  = var.location
  name      = var.name
  parent_id = var.parent_id
  type      = var.resource_types.network_bastion_hosts
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
  ignore_body_changes    = local.ignore_body_changes.network_bastion_hosts
  response_export_values = ["properties.dnsName"]
  retry                  = var.retry
  tags                   = var.tags

  timeouts {
    create = local.timeouts.network_bastion_hosts.create
    delete = local.timeouts.network_bastion_hosts.delete
    read   = local.timeouts.network_bastion_hosts.read
    update = local.timeouts.network_bastion_hosts.update
  }
}

# A `moved` chain cannot cross providers (azurerm to azapi to azapi fails at plan time),
# so the upstream resource labels are kept and there is one cross-type move.
# v0.7.0 to v0.9.0 deployments already use these addresses and need no move.
# v0.6.0 or earlier with `sku = "Developer"` cannot be moved: `azurerm_bastion_host.this`
# has no `count`, so its one move slot goes to the non-Developer path.
moved {
  from = azurerm_bastion_host.this
  to   = azapi_resource.bastion[0]
}

# The public IP module is a pre-release candidate pinned to a commit. Before release this
# reverts to `source = "Azure/avm-res-network-publicipaddress/azurerm"` with the released
# version. The module's own `moved` blocks handle its AzureRM to AzAPI state, so the module
# address does not change.
module "public_ip_address" {
  # tflint-ignore: avm_terraform_module_source_required // pre-release candidate pinned to an immutable commit; reverts to the registry source on release
  source = "git::https://github.com/Git-PrinceNagar/terraform-azurerm-avm-res-network-publicipaddress.git?ref=38014e6831db544cad1105e33b9f4bfebcb36dab"
  count  = var.ip_configuration != null ? (var.ip_configuration.create_public_ip == true ? 1 : 0) : var.sku == "Developer" ? 0 : 1

  location            = var.location
  name                = coalesce(var.ip_configuration.public_ip_address_name, "pip-${var.name}")
  parent_id           = var.parent_id
  enable_telemetry    = var.enable_telemetry
  ignore_body_changes = var.ignore_body_changes.public_ip_address
  resource_types      = var.resource_types.public_ip_address
  retry               = var.retry
  sku                 = "Standard"
  tags = var.ip_configuration.public_ip_tags != null ? (
    var.ip_configuration.public_ip_merge_with_module_tags) ? merge(
    var.tags, var.ip_configuration.public_ip_tags) : (
    var.ip_configuration.public_ip_tags) : (
  var.ip_configuration.public_ip_merge_with_module_tags) ? var.tags : {}
  timeouts = var.timeouts
  zones    = [for zone in var.zones : parseint(zone, 10)]
}

# Reads a public IP the consumer supplied, only to compare its zones with the Bastion
# host's in the precondition on `azapi_resource.bastion`.
data "azapi_resource" "public_ip" {
  count = var.ip_configuration != null ? (var.ip_configuration.create_public_ip == false && var.private_only_enabled == false ? 1 : 0) : 0

  resource_id            = var.ip_configuration.public_ip_address_id
  type                   = var.resource_types.network_public_ip_addresses
  response_export_values = ["zones"]

  timeouts {
    read = local.timeouts.network_bastion_hosts.read
  }
}
