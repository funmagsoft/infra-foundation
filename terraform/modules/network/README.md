# Network Module

Creates the base virtual network, subnets, and network security groups for the ecare foundation layer.

## Resources
- Virtual Network
- Subnets: AKS, Data (private endpoints), Management, optional Gateway
- Network Security Groups (AKS, Data, Management) with default rules
- NSG rule for SSH to the management subnet (optional, based on allowed IPs)
- NSG ↔ Subnet associations

## Inputs (key)
- `resource_group_name` (string) – target RG
- `location` (string) – Azure region
- `vnet_name`, `vnet_cidr` (string)
- `aks_subnet_name`, `aks_subnet_cidr` (string)
- `data_subnet_name`, `data_subnet_cidr` (string)
- `mgmt_subnet_name`, `mgmt_subnet_cidr` (string)
- `gateway_subnet_cidr` (string) – required if `enable_vpn_gateway = true`
- `enable_vpn_gateway` (bool, default `false`)
- `aks_nsg_name`, `data_nsg_name`, `mgmt_nsg_name` (string)
- `mgmt_subnet_allowed_ssh_ips` (list(string), default `[]`) – if non-empty, creates `AllowSSHInbound` on mgmt NSG (priority 200)
- `tags` (map(string), default `{}`)

## Outputs
- `vnet_id`, `vnet_name`
- Subnet IDs: `aks_subnet_id`, `data_subnet_id`, `mgmt_subnet_id`, `gateway_subnet_id` (optional)
- NSG IDs: `aks_nsg_id`, `data_nsg_id`, `mgmt_nsg_id`

## Usage (example)
```hcl
module "network" {
  source = "../../modules/network"

  resource_group_name = data.azurerm_resource_group.main.name
  location            = local.location

  vnet_name = "vnet-ecare-dev"
  vnet_cidr = "10.1.0.0/16"

  aks_subnet_name  = "snet-ecare-dev-aks"
  aks_subnet_cidr  = "10.1.1.0/24"
  aks_nsg_name     = "nsg-ecare-dev-aks"

  data_subnet_name = "snet-ecare-dev-data"
  data_subnet_cidr = "10.1.2.0/24"
  data_nsg_name    = "nsg-ecare-dev-data"

  mgmt_subnet_name = "snet-ecare-dev-mgmt"
  mgmt_subnet_cidr = "10.1.3.0/24"
  mgmt_nsg_name    = "nsg-ecare-dev-mgmt"

  mgmt_subnet_allowed_ssh_ips = ["91.150.222.105"]

  enable_vpn_gateway  = false
  gateway_subnet_cidr = "10.1.4.0/24"

  tags = local.common_tags
}
```

## Notes
- If `mgmt_subnet_allowed_ssh_ips` is empty, SSH from the internet remains blocked by `DenyAllInbound`.
- Gateway subnet is only created when `enable_vpn_gateway = true`.

