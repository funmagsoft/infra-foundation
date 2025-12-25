variable "resource_group_name" {
  description = "Name of the Resource Group"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "vpn_gateway_name" {
  description = "Name of the VPN Gateway"
  type        = string
}

variable "public_ip_name" {
  description = "Name of the Public IP for VPN Gateway"
  type        = string
}

variable "gateway_subnet_id" {
  description = "ID of the Gateway Subnet"
  type        = string
}

variable "vpn_gateway_sku" {
  description = "SKU for VPN Gateway"
  type        = string
  default     = "VpnGw1"
}

variable "vpn_client_address_space" {
  description = "Address space for VPN clients"
  type        = string
  default     = "192.168.255.0/24"
}

variable "vpn_root_cert_name" {
  description = "Name of the root certificate for VPN"
  type        = string
}

variable "vpn_root_cert_data" {
  description = "Root certificate data for VPN (base64 encoded)"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
