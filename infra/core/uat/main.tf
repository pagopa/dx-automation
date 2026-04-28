module "azure-UAT-DEVEX_core" {
  source  = "pagopa-dx/azure-core-infra/azurerm"
  version = "~> 4.0"

  providers = {
    azurerm = azurerm.UAT-DEVEX
  }

  environment = merge(local.environment, local.azure_accounts.UAT-DEVEX, {
    app_name = "core"
  })

  tags = merge(local.tags, {
    Source = "https://github.com/pagopa/dx-automation/blob/main/infra/core/uat"
  })
}