# Deploy Private DNS zones
module "private_dns" {
  source = "../../modules/private-dns"

  resource_group_name = data.azurerm_resource_group.main.name
  vnet_id             = module.network.vnet_id
  vnet_name           = module.network.vnet_name

  tags = local.common_tags

  depends_on = [module.network]
}

