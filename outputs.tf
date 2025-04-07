output "dns_name" {
  description = "The FQDN of the Azure Bastion resource"
  value       = var.sku == "Developer" ? azapi_resource.bastion_developer[0].output.properties.dnsName : azapi_resource.bastion[0].output.properties.dnsName
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
  value       = var.sku == "Developer" ? azapi_resource.bastion_developer[0].id : azapi_resource.bastion[0].id
}
