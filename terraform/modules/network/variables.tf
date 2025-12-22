variable "resource_group_name" {
  description = "Name of the Resource Group"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "vnet_name" {
  description = "Name of the Virtual Network"
  type        = string
}

variable "vnet_cidr" {
  description = "CIDR block for the Virtual Network"
  type        = string
}

variable "aks_subnet_name" {
  description = "Name of the AKS subnet"
  type        = string
}

variable "aks_subnet_cidr" {
  description = "CIDR block for AKS subnet"
  type        = string
}

variable "data_subnet_name" {
  description = "Name of the Data subnet"
  type        = string
}

variable "data_subnet_cidr" {
  description = "CIDR block for Data subnet"
  type        = string
}

variable "mgmt_subnet_name" {
  description = "Name of the Management subnet"
  type        = string
}

variable "mgmt_subnet_cidr" {
  description = "CIDR block for Management subnet"
  type        = string
}

variable "gateway_subnet_cidr" {
  description = "CIDR block for Gateway subnet"
  type        = string
}

variable "aks_nsg_name" {
  description = "Name of the NSG for AKS subnet"
  type        = string
}

variable "data_nsg_name" {
  description = "Name of the NSG for Data subnet"
  type        = string
}

variable "mgmt_nsg_name" {
  description = "Name of the NSG for Management subnet"
  type        = string
}

variable "enable_vpn_gateway" {
  description = "Enable VPN Gateway subnet"
  type        = bool
  default     = false
}

variable "mgmt_subnet_allowed_ssh_ips" {
  description = "List of allowed source IP addresses/CIDR blocks for SSH access to mgmt subnet. If empty, SSH from internet is blocked."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

