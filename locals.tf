
# LOCALS Description:
# public_ip_resource_id: This is the resource ID of the public IP resource to be associated with the Azure Bastion Host. This depends on whether a public IP was provided or not.
# public_ip_zone_config: The zone configuration of the public IP address. We use this to ensure the configuration matches the Azure Bastion Host.
# role_definition_resource_substring: This is the substring used to identify the role definition resource in Azure.

locals {
  public_ip_resource_id              = length(module.public_ip_address) == 0 ? (length(data.azurerm_public_ip.this) == 0 ? null : { id = data.azurerm_public_ip.this[0].id }) : { id = module.public_ip_address[0].resource_id }
  public_ip_zone_config              = length(module.public_ip_address) == 0 ? (length(data.azurerm_public_ip.this) == 0 ? [] : data.azurerm_public_ip.this[0].zones) : var.zones
  role_definition_resource_substring = "/providers/Microsoft.Authorization/roleDefinitions"
}
