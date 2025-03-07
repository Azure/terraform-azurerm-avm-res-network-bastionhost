locals {
  public_ip_resource_id              = var.ip_configuration.public_ip_address_id != null ? data.azurerm_public_ip.this[0] : module.public_ip_address[0].resource_id
  public_ip_zone_config              = var.ip_configuration.public_ip_address_id != null ? data.azurerm_public_ip.this[0].zones : var.zones
  role_definition_resource_substring = "/providers/Microsoft.Authorization/roleDefinitions"
}
