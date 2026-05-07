output "vnet_id" {
  description = "The ID of the virtual network"
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "The name of the virtual network"
  value       = azurerm_virtual_network.main.name
}

output "apim_subnet_id" {
  description = "The ID of the APIM subnet"
  value       = azurerm_subnet.apim.id
}

output "apim_subnet_name" {
  description = "The name of the APIM subnet"
  value       = azurerm_subnet.apim.name
}

output "private_endpoint_subnet_id" {
  description = "The ID of the private endpoint subnet"
  value       = azurerm_subnet.private_endpoints.id
}

output "private_endpoint_subnet_name" {
  description = "The name of the private endpoint subnet"
  value       = azurerm_subnet.private_endpoints.name
}

output "openai_private_dns_zone_id" {
  description = "The ID of the OpenAI private DNS zone"
  value       = azurerm_private_dns_zone.openai.id
}

output "keyvault_private_dns_zone_id" {
  description = "The ID of the Key Vault private DNS zone"
  value       = azurerm_private_dns_zone.keyvault.id
}



output "monitor_private_dns_zone_id" {
  description = "The ID of the Monitor private DNS zone"
  value       = azurerm_private_dns_zone.monitor.id
}

output "blob_private_dns_zone_id" {
  description = "The ID of the Blob private DNS zone"
  value       = azurerm_private_dns_zone.blob.id
}

output "logicapp_subnet_id" {
  description = "The ID of the Logic App subnet"
  value       = azurerm_subnet.logicapp.id
}

output "logicapp_subnet_name" {
  description = "The name of the Logic App subnet"
  value       = azurerm_subnet.logicapp.name
}