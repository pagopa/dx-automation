data "azurerm_resource_group" "azure-UAT-DEVEX_common" {
  provider = azurerm.UAT-DEVEX
  name = provider::dx::resource_name(merge(local.environment, {
    resource_type   = "resource_group",
    name            = "common"
    instance_number = 1
  }, local.azure_accounts.UAT-DEVEX))
}

import {
  to = module.azure-UAT-DEVEX_core.azurerm_resource_group.common
  id = data.azurerm_resource_group.azure-UAT-DEVEX_common.id
}

data "azurerm_key_vault" "azure-UAT-DEVEX_common" {
  provider = azurerm.UAT-DEVEX
  name = provider::dx::resource_name(merge(local.environment, {
    resource_type   = "key_vault"
    name            = "common"
    instance_number = 1
  }, local.azure_accounts.UAT-DEVEX))
  resource_group_name = data.azurerm_resource_group.azure-UAT-DEVEX_common.name
}

import {
  to = module.azure-UAT-DEVEX_core.module.key_vault.azurerm_key_vault.common
  id = data.azurerm_key_vault.azure-UAT-DEVEX_common.id
}