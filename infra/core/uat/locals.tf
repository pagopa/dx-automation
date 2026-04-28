locals {
  environment = {
    prefix          = "dx"
    env_short       = "u"
    domain          = "auto"
    instance_number = "01"
  }

  azure_accounts = {
    UAT-DEVEX = {
      location = "italynorth"
    }
  }

  tags = {
    CreatedBy      = "Terraform"
    Environment    = "Uat"
    CostCenter     = "TS000"
    BusinessUnit   = "DevEx"
    ManagementTeam = "Developer Experience"
  }
}