output "dns_name" {
  description = "The FQDN of the Azure Bastion resource"
  # `try` covers a state that just arrived through a `moved` block and has no exported
  # response yet. Unknown values still propagate, so the adoption plan shows "known after apply".
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
