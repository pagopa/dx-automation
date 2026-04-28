locals {
  bootstrapper_tags = merge(local.tags, {
    Source = "https://github.com/pagopa/dx-automation/blob/main/infra/bootstrapper/uat"
  })
}

module "azure-UAT-DEVEX_core_values" {
  source  = "pagopa-dx/azure-core-values-exporter/azurerm"
  version = "~> 0.0"

  providers = {
    azurerm = azurerm.UAT-DEVEX
  }

  core_state = {
    resource_group_name  = "dx-u-itn-tfstate-rg-01"
    storage_account_name = "dxuitntfstatest01"
    subscription_id      = "4eed9304-ce39-4d3f-bc84-f7964523d5e8"
    container_name       = "terraform-state"
    key                  = "dx.core.uat.tfstate"
  }
}

module "azure-UAT-DEVEX_bootstrap" {
  source  = "pagopa-dx/azure-github-environment-bootstrap/azurerm"
  version = "~> 3.0"

  providers = {
    azurerm = azurerm.UAT-DEVEX
  }

  environment = merge(local.environment, local.azure_accounts.UAT-DEVEX)

  subscription_id = module.azure-UAT-DEVEX_core_values.subscription_id
  tenant_id       = module.azure-UAT-DEVEX_core_values.tenant_id

  entraid_groups = {
    admins_object_id    = data.azuread_group.admins.object_id
    devs_object_id      = data.azuread_group.developers.object_id
    externals_object_id = data.azuread_group.externals.object_id
  }

  terraform_storage_account = {
    name                = "dxuitntfstatest01"
    resource_group_name = "dx-u-itn-tfstate-rg-01"
  }

  repository = {
    owner = "pagopa"
    name  = "dx-automation"
  }

  github_private_runner = {
    container_app_environment_id       = module.azure-UAT-DEVEX_core_values.github_runner.environment_id
    container_app_environment_location = local.azure_accounts.UAT-DEVEX.location
    labels = [
      "uat"
    ]
    key_vault = {
      name                = module.azure-UAT-DEVEX_core_values.common_key_vault.name
      resource_group_name = module.azure-UAT-DEVEX_core_values.common_key_vault.resource_group_name
      use_rbac            = true
    }
    use_github_app = true
  }

  pep_vnet_id                        = module.azure-UAT-DEVEX_core_values.common_vnet.id
  private_dns_zone_resource_group_id = module.azure-UAT-DEVEX_core_values.network_resource_group_id
  opex_resource_group_id             = module.azure-UAT-DEVEX_core_values.opex_resource_group_id

  tags = local.bootstrapper_tags
}

resource "azurerm_role_assignment" "infra_cd_user_access_admin_common_rg_UAT-DEVEX" {
  provider = azurerm.UAT-DEVEX

  scope                = module.azure-UAT-DEVEX_core_values.common_resource_group_id
  role_definition_name = "User Access Administrator"
  principal_id         = module.azure-UAT-DEVEX_bootstrap.identities.infra.cd.principal_id
}

resource "azurerm_role_assignment" "infra_cd_kv_secrets_officer_common_UAT-DEVEX" {
  provider = azurerm.UAT-DEVEX

  scope                = module.azure-UAT-DEVEX_core_values.common_key_vault.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = module.azure-UAT-DEVEX_bootstrap.identities.infra.cd.principal_id
}

resource "azurerm_role_assignment" "infra_ci_kv_secrets_user_common_UAT-DEVEX" {
  provider = azurerm.UAT-DEVEX

  scope                = module.azure-UAT-DEVEX_core_values.common_key_vault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.azure-UAT-DEVEX_bootstrap.identities.infra.ci.principal_id
}