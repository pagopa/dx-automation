data "azuread_group" "admins" {
  display_name = "dx-u-auto-adgroup-admin"
}

data "azuread_group" "developers" {
  display_name = "dx-u-auto-adgroup-developers"
}

data "azuread_group" "externals" {
  display_name = "dx-u-auto-adgroup-externals"
}