terraform {
  backend "azurerm" {
    resource_group_name  = "rg-ecare-dev"
    storage_account_name = "tfstatehycomecaredev"
    container_name       = "tfstate"
    key                  = "infra-foundation/terraform.tfstate"
    use_azuread_auth     = true
  }
}
