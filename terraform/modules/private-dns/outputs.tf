output "postgresql_zone_id" {
  description = "ID of the PostgreSQL Private DNS Zone"
  value       = azurerm_private_dns_zone.postgresql.id
}

output "keyvault_zone_id" {
  description = "ID of the Key Vault Private DNS Zone"
  value       = azurerm_private_dns_zone.keyvault.id
}

output "blob_zone_id" {
  description = "ID of the Blob Storage Private DNS Zone"
  value       = azurerm_private_dns_zone.blob.id
}

output "file_zone_id" {
  description = "ID of the File Storage Private DNS Zone"
  value       = azurerm_private_dns_zone.file.id
}

output "servicebus_zone_id" {
  description = "ID of the Service Bus Private DNS Zone"
  value       = azurerm_private_dns_zone.servicebus.id
}

output "acr_zone_id" {
  description = "ID of the ACR Private DNS Zone"
  value       = azurerm_private_dns_zone.acr.id
}

