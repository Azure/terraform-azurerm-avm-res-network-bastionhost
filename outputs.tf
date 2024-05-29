output "dns_name" {
  description = "The FQDN of the Azure Bastion resource"
  value       = azurerm_bastion_host.this.dns_name
}

output "name" {
  description = "The name of the Azure Bastion resource"
  value       = azurerm_bastion_host.this.name
}

output "resource" {
  description = "The Azure Bastion resource"
  value       = azurerm_bastion_host.this
}

output "resource_id" {
  description = "The ID of the Azure Bastion resource"
  value       = azurerm_bastion_host.this.id
}
