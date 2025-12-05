terraform {
  backend "azurerm" {
    resource_group_name  = "rg-ecare-stage"
    storage_account_name = "tfstatefmsecarestage"
    container_name       = "tfstate"
    key                  = "infra-foundation/terraform.tfstate"
    use_azuread_auth     = true
  }
}
