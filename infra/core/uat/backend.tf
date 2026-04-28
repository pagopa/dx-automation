terraform {
  backend "azurerm" {
    resource_group_name  = "dx-u-itn-tfstate-rg-01"
    storage_account_name = "dxuitntfstatest01"
    container_name       = "terraform-state"
    key                  = "dx.core.uat.tfstate"
    subscription_id      = "4eed9304-ce39-4d3f-bc84-f7964523d5e8"
    use_azuread_auth     = true
  }
}