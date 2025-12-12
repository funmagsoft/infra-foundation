variable "resource_group_name" {
  description = "Name of the Resource Group"
  type        = string
}

variable "vnet_id" {
  description = "ID of the Virtual Network to link DNS zones to"
  type        = string
}

variable "vnet_name" {
  description = "Name of the Virtual Network"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
