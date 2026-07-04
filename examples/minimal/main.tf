# Minimal call: one Logic App Standard on a dedicated WS1 plan with a created keys-on storage
# account and the secure defaults (https_only, basic auth off). Applied then destroyed in one CI
# run.
locals {
  location   = lookup(var.regions, var.loc, "uksouth")
  rg_name    = "rg-${var.short}-${var.loc}-${terraform.workspace}-001"
  logic_name = "logic-${var.short}-${var.loc}-${terraform.workspace}-001"
}

module "tags" {
  source  = "libre-devops/tags/azurerm"
  version = "~> 4.0"

  cost_centre     = "1888/67"
  owner           = "platform@example.com"
  deployed_branch = var.deployed_branch
  deployed_repo   = var.deployed_repo
}

module "rg" {
  source  = "libre-devops/rg/azurerm"
  version = "~> 4.0"

  resource_groups = [{ name = local.rg_name, location = local.location, tags = module.tags.tags }]
}

module "logic_app_standard" {
  source = "../../"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  logic_apps = {
    (local.logic_name) = {}
  }
}

output "default_hostname" {
  value = module.logic_app_standard.default_hostnames[local.logic_name]
}

output "resource_group_name" {
  value = local.rg_name
}
