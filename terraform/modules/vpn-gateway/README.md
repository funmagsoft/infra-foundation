# VPN Gateway Module

Creates an optional VPN Gateway with Public IP for site-to-site/client VPN scenarios.

## Resources
- Public IP for VPN Gateway
- Virtual Network Gateway (VPN)

## Inputs (key)
- `resource_group_name` (string)
- `location` (string)
- `vpn_gateway_name` (string)
- `public_ip_name` (string)
- `gateway_subnet_id` (string) – required
- `vpn_gateway_sku` (string, default `VpnGw1`)
- `vpn_client_address_space` (string, default `"192.168.255.0/24"`)
- `vpn_root_cert_name` (string, default `"VPN-Root-Cert"`)
- `vpn_root_cert_data` (string, base64, default `""`, sensitive)
- `tags` (map(string), default `{}`)

## Outputs
- `vpn_gateway_id`
- `public_ip_address`

## Usage (example)
```hcl
module "vpn_gateway" {
  count  = var.enable_vpn_gateway ? 1 : 0
  source = "../../modules/vpn-gateway"

  resource_group_name = data.azurerm_resource_group.main.name
  location            = local.location

  vpn_gateway_name = "vgw-ecare-dev"
  public_ip_name   = "pip-vgw-ecare-dev"
  gateway_subnet_id = module.network.gateway_subnet_id

  vpn_gateway_sku          = "VpnGw1"
  vpn_client_address_space = "192.168.255.0/24"
  vpn_root_cert_name       = "VPN-Root-Cert"
  vpn_root_cert_data       = var.vpn_root_cert_data

  tags = local.common_tags
}
```

## Notes
- Requires an existing GatewaySubnet in the VNet (provided by the network module when `enable_vpn_gateway = true`).
- `vpn_root_cert_data` is sensitive; keep it out of version control.

