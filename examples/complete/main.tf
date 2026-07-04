# A fuller Logic App Standard: a shared WS1 plan, a system-assigned identity, Application Insights
# wired through app settings, always_on, a TLS 1.3 floor, CORS for the portal designer, and a
# connection string. Applied then destroyed in one CI run.
locals {
  location   = lookup(var.regions, var.loc, "uksouth")
  rg_name    = "rg-${var.short}-${var.loc}-${terraform.workspace}-002"
  law_name   = "log-${var.short}-${var.loc}-${terraform.workspace}-002"
  appi_name  = "appi-${var.short}-${var.loc}-${terraform.workspace}-002"
  logic_name = "logic-${var.short}-${var.loc}-${terraform.workspace}-002"
  plan_name  = "asp-shared-${var.short}-${var.loc}-${terraform.workspace}-002"
}

module "tags" {
  source  = "libre-devops/tags/azurerm"
  version = "~> 4.0"

  cost_centre     = "1888/67"
  owner           = "platform@example.com"
  deployed_branch = var.deployed_branch
  deployed_repo   = var.deployed_repo
  additional_tags = { Application = "terraform-azurerm-logic-app-standard" }
}

module "rg" {
  source  = "libre-devops/rg/azurerm"
  version = "~> 4.0"

  resource_groups = [{ name = local.rg_name, location = local.location, tags = module.tags.tags }]
}

module "log_analytics" {
  source  = "libre-devops/log-analytics-workspace/azurerm"
  version = "~> 4.0"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  log_analytics_workspaces = { (local.law_name) = {} }
}

module "application_insights" {
  source  = "libre-devops/application-insights/azurerm"
  version = "~> 4.0"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  application_insights = {
    (local.appi_name) = {
      workspace_id = module.log_analytics.workspace_ids[local.law_name]
    }
  }
}

module "logic_app_standard" {
  source = "../../"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  service_plans = {
    (local.plan_name) = { sku_name = "WS1" }
  }

  logic_apps = {
    (local.logic_name) = {
      service_plan_key = local.plan_name

      identity = { type = "SystemAssigned" }

      app_settings = {
        APPLICATIONINSIGHTS_CONNECTION_STRING = module.application_insights.connection_strings[local.appi_name]
      }

      connection_strings = [
        { name = "example", type = "Custom", value = "not-a-real-secret" }
      ]

      site_config = {
        always_on       = true
        http2_enabled   = true
        min_tls_version = "1.3"

        cors = {
          allowed_origins = ["https://portal.azure.com"]
        }
      }
    }
  }
}

output "default_hostname" {
  value = module.logic_app_standard.default_hostnames[local.logic_name]
}

output "logic_app_id" {
  value = module.logic_app_standard.logic_app_ids[local.logic_name]
}

output "resource_group_name" {
  value = local.rg_name
}
