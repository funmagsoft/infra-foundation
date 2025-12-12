output "vnet_id" {
  description = "ID of the Virtual Network"
  value       = module.network.vnet_id
}

output "vnet_name" {
  description = "Name of the Virtual Network"
  value       = module.network.vnet_name
}

output "aks_subnet_id" {
  description = "ID of the AKS subnet"
  value       = module.network.aks_subnet_id
}

output "data_subnet_id" {
  description = "ID of the Data subnet"
  value       = module.network.data_subnet_id
}

output "mgmt_subnet_id" {
  description = "ID of the Management subnet"
  value       = module.network.mgmt_subnet_id
}

output "gateway_subnet_id" {
  description = "ID of the Gateway subnet"
  value       = module.network.gateway_subnet_id
}

output "aks_nsg_id" {
  description = "ID of the AKS NSG"
  value       = module.network.aks_nsg_id
}

output "data_nsg_id" {
  description = "ID of the Data NSG"
  value       = module.network.data_nsg_id
}

output "mgmt_nsg_id" {
  description = "ID of the Management NSG"
  value       = module.network.mgmt_nsg_id
}

output "private_dns_zones" {
  description = "Private DNS Zone IDs"
  value = {
    postgresql = module.private_dns.postgresql_zone_id
    keyvault   = module.private_dns.keyvault_zone_id
    blob       = module.private_dns.blob_zone_id
    file       = module.private_dns.file_zone_id
    servicebus = module.private_dns.servicebus_zone_id
    acr        = module.private_dns.acr_zone_id
  }
}

output "vpn_gateway_id" {
  description = "ID of the VPN Gateway"
  value       = var.enable_vpn_gateway ? module.vpn_gateway[0].vpn_gateway_id : null
}

output "vpn_public_ip" {
  description = "Public IP address of VPN Gateway"
  value       = var.enable_vpn_gateway ? module.vpn_gateway[0].public_ip_address : null
}

