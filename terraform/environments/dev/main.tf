terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }
}

provider "azurerm" {
  features {}
  
  subscription_id = var.subscription_id
}

# Reference existing Resource Group (created in Phase 0)
data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

# Local variables
locals {
  environment = "dev"
  project     = "ecare"
  location    = data.azurerm_resource_group.main.location

  common_tags = {
    Environment   = local.environment
    Project       = local.project
    ManagedBy     = "Terraform"
    Phase         = "Foundation"
    GitRepository = "infra-foundation"
    TerraformPath = "terraform/environments/${local.environment}"
  }
}

