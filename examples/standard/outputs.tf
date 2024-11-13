output "bastion_host" {
  description = "The name of the bastion host resource"
  value       = module.azure_bastion.resource
}

output "bastion_host_id" {
  description = "The id of the bastion host resource"
  value       = module.azure_bastion.resource_id
}
