data "azuread_group" "admins" {
  display_name = "dx-u-adgroup-admin"
}

data "azuread_group" "developers" {
  display_name = "dx-u-adgroup-developers"
}

data "azuread_group" "externals" {
  display_name = "dx-u-adgroup-externals"
}
