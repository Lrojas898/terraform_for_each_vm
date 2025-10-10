# Configure the Microsoft Azure Provider
terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "devops-terraform-state-rg"
    storage_account_name = "devopsterraformstate001"
    container_name       = "tfstate"
    key                  = "devops-infrastructure.tfstate"
  }
}

provider "azurerm" {
  features {}
  subscription_id = "44127b49-3951-4881-8cf2-9cff7a88e6ca"
}