# `var.sku` selects between the two mutually exclusive Bastion writers in `main.tf`;
# exactly one of them has `count = 1` for any given value. The addresses changed in
# this release (`bastion` -> `this`, `bastion_developer` -> `developer`), but the
# output names, types and semantics did not.


output "dns_name" {
  description = "The FQDN of the Azure Bastion resource"
  # TFFR: a discrete output mapped from `azapi_resource.bastion.output`, which is why
  # `response_export_values` on both writers is non-empty and must stay that way.
  # `try(..., null)` guards the one window where `.output` is legitimately absent: a
  # state that has just arrived through a `moved` block has no exported response yet,
  # because the export list is config-only and the move had nothing to populate it
  # from. `try` propagates unknowns rather than swallowing them, so during the
  # adoption plan this still reports "known after apply" rather than a spurious null.
  value = var.sku == "Developer" ? try(azapi_resource.bastion_developer[0].output.properties.dnsName, null) : try(azapi_resource.bastion[0].output.properties.dnsName, null)
}

output "name" {
  description = "The name of the Azure Bastion resource"
  value       = var.sku == "Developer" ? azapi_resource.bastion_developer[0].name : azapi_resource.bastion[0].name
}

output "resource" {
  description = "The Azure Bastion resource"
  value       = var.sku == "Developer" ? azapi_resource.bastion_developer[0] : azapi_resource.bastion[0]
}

output "resource_id" {
  description = "The ID of the Azure Bastion resource"
  value       = local.bastion_resource_id
}
