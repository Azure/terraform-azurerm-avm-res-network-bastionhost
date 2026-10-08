# =============================================================================
# AZURERM -> AZAPI, PROVIDER MIGRATION IN PLACE.
#
# Same module, same `count` boundary, same keys. Every state move is a
# whole-resource move expressed as a `moved` block, so a consumer bumps the
# module version and nothing else. See `.github/skills/avm-tf-migration/SKILL.md`.
#
# 🔴 READ THIS BEFORE EDITING THE `moved` BLOCKS. Terraform gives every source
# address exactly ONE destination and every destination exactly ONE source.
# Measured with Terraform 1.14.9 against real state:
#   - two `moved` blocks sharing a `from` -> "Ambiguous move statements ...
#     Each resource instance can move to only one destination instance."
#   - two `moved` blocks sharing a `to`   -> "Ambiguous move statements ...
#     Each resource instance can have moved from only one source instance."
# Both are PLAN-time errors raised statically, whatever is in state, and
# `terraform validate` does NOT catch them. A SAME-PROVIDER chain `A -> B -> C`
# resolves to a no-op even when `B` exists in neither configuration nor state --
# but a chain that CROSSES providers does not work at all, which is why there is
# exactly one `moved` block for the Bastion host below. See the note there.
#
# 🔴 THE ONE COHORT THIS CANNOT RESCUE: a deployment created at v0.6.0 or
# earlier with `sku = "Developer"`. `azurerm_bastion_host.this` had no `count`,
# so it is a single address with a single move slot, and the two AzAPI writers
# it could become are different addresses. The slot is spent on the
# non-Developer path, which is the common one. `terraform state mv` is not an
# escape hatch either -- it refuses to move between different resource types --
# so there is no consumer command to publish. Those deployments get the
# destroy-and-recreate that upstream v0.7.0 already imposed on them when it
# swapped the provider with no `moved` block at all. Documented, not hidden.
# =============================================================================

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
  # ⚖️ KEPT, DELIBERATELY, and the cost is known.
  #
  # The plan modifier behind this attribute is `RequiresReplaceIfNotNull`
  # (`planmodifierdynamic/dynamic_requires_replace.go`), whose whole body is
  # `resp.RequiresReplace = !planNull && !stateNull`. A state that arrived
  # through a `moved` block holds NULL here, because the attribute is
  # config-only and there was nothing for the read to populate. So at adoption
  # it does not fire: the first plan after upgrading is an UPDATE, never a
  # replacement. From the second apply onwards the state value is populated and
  # a genuine `sku` change does replace.
  #
  # That update is a full PUT, because the attribute carries no
  # `skip_on:"update"` tag and therefore defeats `skip.CanSkipExternalRequest`.
  # Here that is harmless and it is parity: this is a plain full writer with no
  # `ignore_changes` on `body`, so `CreateUpdate` PUTs `plan.Body` -- the body
  # built from today's configuration -- and not a stale `state.body`. Measured
  # by reading `azapi_resource.go` `CreateUpdate` at azapi 2.13.0:
  # `unmarshalBody(plan.Body, &body)`. `azurerm_bastion_host` likewise rebuilt
  # its payload from scratch on every update.
  #
  # ⚖️ RECONCILED WITH THE SIDE-CAR RULING, NOT IGNORING IT. The vWAN pattern
  # module positively PROHIBITS this attribute on
  # `modules/site-to-site-gateway` and removed it from
  # `modules/expressroute-gateway` ("RULING 2", 2026-09-28). Both rulings rest on
  # one premise stated in their own text -- "that update is a FULL PUT ... of the
  # stale `state.body`" -- which holds only because those are CREATE-ONLY writers
  # carrying `lifecycle { ignore_changes = [body] }` alongside an
  # `azapi_update_resource` merge writer. Terraform plans the prior state value
  # for an ignored attribute, so on those resources `plan.Body IS state.Body`,
  # and the adoption PUT drops `properties.connections`. This resource has no
  # `ignore_changes` on `body` and no merge writer, so that premise is absent and
  # the ruling does not reach it. 🔴 IF A FUTURE CHANGE ADDS
  # `ignore_changes = [body]` HERE, THIS ATTRIBUTE MUST BE REMOVED IN THE SAME
  # COMMIT.
  #
  # 🟡 DEVIATION FROM AZURERM, recorded and INHERITED rather than introduced.
  # AzureRM did not mark `sku` ForceNew outright; it used `ForceNewIfChange`
  # with a `skuWeight` comparison, so it replaced only on a DOWNGRADE and
  # updated in place on an upgrade. This replaces on any change. That behaviour
  # arrived in v0.7.0 with the original AzAPI swap and is preserved here
  # unchanged, because removing it would be a second behaviour change smuggled
  # into a state migration.
  replace_triggers_external_values = [
    var.sku
  ]
  # TFFR4. Non-empty because `outputs.tf` publishes `dns_name` from
  # `.output.properties.dnsName`.
  #
  # 🔴 DO NOT ADD `lifecycle { ignore_changes = [response_export_values] }`
  # HERE. That idiom exists for CREATE-ONLY writers, where a null-vs-set
  # difference at adoption would drag a pinned `state.body` into a PUT. This
  # writer is not one, and ignoring the attribute would pin the moved-in NULL
  # forever: `.output` would never populate and `dns_name` would fail to
  # evaluate. The adoption-time update is what fills `.output`, so it is
  # required, not incidental.
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
  ignore_body_changes = local.ignore_body_changes.network_bastion_hosts
  # TFFR4. Same export as the writer above, for the same output.
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

# --- Bastion host state move -------------------------------------------------
#
# Exactly ONE `moved` block, and it is the only one that can exist here.
#
# This module keeps the UPSTREAM resource labels `bastion` and
# `bastion_developer` (v0.9.0 and origin/main both ship them). That is a
# deliberate constraint, not an accident of history: because the addresses do
# not change, a v0.7.0-v0.9.0 consumer needs NO move at all for either SKU, and
# the only state transition left to express is the v0.6.0 AzureRM -> AzAPI hop
# below. An earlier revision of this branch renamed these to `this`/`developer`
# and bridged the gap with a MOVE CHAIN. That chain does not work, and the
# rename was never justified, so both were reverted.
#
# MEASURED, azapi 2.13.0 + Terraform 1.14: a `moved` CHAIN CANNOT CROSS
# azurerm -> azapi -> azapi. `refactoring.ApplyMoves` does not collapse a chain;
# it walks each hop separately and issues a separate `MoveResourceState` gRPC
# call per hop. azapi's `MoveResourceState` accepts an `azurerm_*` source type
# only, so the second hop (`azapi_resource.bastion[0]` -> an azapi target) is
# rejected at PLAN time with:
#
#     Error: Invalid source type
#     The `azapi_resource` resource can only be moved from an `azurerm` resource
#
# This is not recoverable from configuration. A standalone azapi -> azapi rename
# is fine (Terraform treats it as an address rename and never calls the RPC);
# it is specifically the hop that FOLLOWS a cross-provider hop that fails.
# Keeping the upstream labels removes the need for any such chain.
#
# Upstream shipped NO `moved` block at any release -- `git log --all -S"moved {"`
# over `*.tf` is empty before this commit -- so the v0.6.0 -> v0.7.0 transition
# was an unmanaged break that this release bridges after the fact.
#
# Cohort coverage:
#   - v0.6.0 and earlier, NON-Developer SKU -> the single cross-type move below.
#   - v0.7.0 to v0.9.0, either SKU          -> no move needed, address unchanged.
#   - v0.6.0 and earlier, Developer SKU     -> NOT recoverable. `azurerm_bastion_host.this`
#     has no `count`, so it owns exactly one `moved` destination and that slot is
#     spent on the non-Developer path above. A second `moved` from the same source
#     is the static error `Ambiguous move statements`, not a runtime choice.
#     Documented as a breaking change in `_header.md`.
moved {
  from = azurerm_bastion_host.this
  to   = azapi_resource.bastion[0]
}

# -----------------------------------------------------------------------------
# ✅ THE LAST AZURERM DEPENDENCY IS GONE. This call now resolves to the AzAPI
# implementation of the public IP module and no `hashicorp/azurerm` provider is
# installed for this module graph any more.
#
# The AzAPI version of `Azure/avm-res-network-publicipaddress/azurerm` is the AzAPI-only
# release. Its breaking change is exactly one input: the AzureRM-era
# `resource_group_name` was DELETED -- not deprecated -- and replaced by a
# REQUIRED `parent_id` carrying the fully-qualified ARM resource-group ID, which
# it validates with `provider::azapi::parse_resource_id` per TFNFR38. That is the
# same contract this module already presents at `var.parent_id`, so the value is
# passed straight through rather than being decomposed into a name. The other 22
# inputs and all four outputs are unchanged, so nothing else in this file or in
# `locals.tf` moves.
#
# STATE: the public IP's own provider hop is handled INSIDE that module, by its
# own `moved` blocks (`azurerm_public_ip.this` -> `azapi_resource.bastion`, plus its
# lock, role assignment and diagnostic setting). Nothing is needed here, because
# the module ADDRESS -- `module.public_ip_address[0]` -- does not change; only the
# implementation behind it does. That is why this stayed a version bump and was
# never inlined: inlining would move the public IP ACROSS a module boundary, a
# COMPOSITION migration, which SKILL.md's "Separate two changes" forbids
# combining with a provider migration.
#
# A consumer no longer needs `provider "azurerm" { features {} }` in their root.
#
# ⚠️ PRE-RELEASE CANDIDATE SOURCE. The AzAPI public IP module is not yet
# published to the registry, so `source` pins an immutable commit of the
# candidate. Before release this reverts to the registry pin:
#
#   source  = "Azure/avm-res-network-publicipaddress/azurerm"
#   version = "<released AzAPI version>"
#
# `version` is deliberately absent because Terraform rejects it on a git source.
# -----------------------------------------------------------------------------
module "public_ip_address" {
  # tflint-ignore: avm_terraform_module_source_required // pre-release candidate pinned to an immutable commit; reverts to the registry source on release
  source = "git::https://github.com/Git-PrinceNagar/terraform-azurerm-avm-res-network-publicipaddress.git?ref=c9f4bd6951e8b9bc8c8ec3fe8a5975b1def750d4"
  count  = var.ip_configuration != null ? (var.ip_configuration.create_public_ip == true ? 1 : 0) : var.sku == "Developer" ? 0 : 1

  location = var.location
  name     = coalesce(var.ip_configuration.public_ip_address_name, "pip-${var.name}")
  # Was `resource_group_name = local.parent_resource_group.resource_group_name`,
  # which was itself a replacement for `split("/", var.parent_id)[4]`. the AzAPI version takes
  # the fully-qualified resource-group ID directly, so the decomposition is gone
  # entirely and `var.parent_id` -- already TFNFR38-validated here -- is forwarded
  # unchanged. TFRMFR1: a resource module takes its parent scope as an ID.
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

# Reads a public IP the consumer supplied through
# `ip_configuration.public_ip_address_id`, solely to compare its zones against
# the Bastion host's in the precondition on `azapi_resource.bastion`.
#
# Replaces `data.azurerm_public_ip.this`. That data source took a name plus a
# resource group name and rebuilt the ID; this one is given the ID directly,
# which removes the `split(...)[4]` index arithmetic and the assumption that the
# public IP lives in the same resource group as the Bastion host. The narrowed
# export keeps `.output` to the one member `locals.tf` consumes.
#
# A data source is never moved, so this address deliberately has no `moved`
# block. Terraform simply drops the old one from state on the next refresh.
data "azapi_resource" "public_ip" {
  count = var.ip_configuration != null ? (var.ip_configuration.create_public_ip == false && var.private_only_enabled == false ? 1 : 0) : 0

  resource_id            = var.ip_configuration.public_ip_address_id
  type                   = var.resource_types.network_public_ip_addresses
  response_export_values = ["zones"]

  timeouts {
    read = local.timeouts.network_bastion_hosts.read
  }
}
