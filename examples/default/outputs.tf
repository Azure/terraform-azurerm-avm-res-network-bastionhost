output "bastion_host" {
  value       = module.azure_bastion.bastion_resource
  description = "The name of the bastion host resource"
}

output "bastion_host_id" {
  value       = module.azure_bastion.bastion_resource
  description = "The id of the bastion host resource"
}
