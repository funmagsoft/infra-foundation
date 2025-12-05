terraform {
  backend "azurerm" {
    resource_group_name  = "rg-ecare-test"
    storage_account_name = "tfstatemagsoftecaretest"
    container_name       = "tfstate"
    key                  = "infra-foundation/terraform.tfstate"
    use_azuread_auth     = true
  }
}
