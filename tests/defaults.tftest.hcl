# Tests for the module. azurerm is mocked (no credentials, no cloud):
#   terraform init -backend=false && terraform test

mock_provider "azurerm" {
  mock_resource "azurerm_storage_account" {
    defaults = {
      id                 = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-001/providers/Microsoft.Storage/storageAccounts/stmock"
      primary_access_key = "bW9ja2tleQ=="
    }
  }

  mock_resource "azurerm_service_plan" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-001/providers/Microsoft.Web/serverFarms/asp-mock"
    }
  }
}

variables {
  resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-001"
  location          = "uksouth"
  tags              = { Environment = "tst" }
}

# One app, nothing but a name: a dedicated WS1 plan, a created keys-on storage account, and the
# secure defaults (https_only, basic auth off).
run "fast_to_get_going" {
  command = apply

  variables {
    logic_apps = {
      "logic-ldo-uks-tst-01" = {}
    }
  }

  assert {
    condition     = azurerm_service_plan.auto["logic-ldo-uks-tst-01"].sku_name == "WS1"
    error_message = "An app with no plan reference should get a dedicated WS1 plan."
  }

  assert {
    condition     = azurerm_storage_account.this["logic-ldo-uks-tst-01"].shared_access_key_enabled != false
    error_message = "Logic App Standard storage must keep shared keys enabled."
  }

  assert {
    condition     = azurerm_logic_app_standard.this["logic-ldo-uks-tst-01"].storage_account_access_key != null
    error_message = "The created account's key should feed the app."
  }

  assert {
    condition     = azurerm_logic_app_standard.this["logic-ldo-uks-tst-01"].https_only == true
    error_message = "https_only should default true."
  }

  assert {
    condition     = azurerm_logic_app_standard.this["logic-ldo-uks-tst-01"].ftp_publish_basic_authentication_enabled == false && azurerm_logic_app_standard.this["logic-ldo-uks-tst-01"].scm_publish_basic_authentication_enabled == false
    error_message = "Basic-auth publishing should default off."
  }

  assert {
    condition     = azurerm_logic_app_standard.this["logic-ldo-uks-tst-01"].version == "~4"
    error_message = "The Functions runtime version should default to ~4."
  }
}

# A shared plan, bring-your-own storage, an identity, connection strings, and site_config.
run "full_surface" {
  command = apply

  variables {
    service_plans = {
      "asp-shared-ldo-uks-tst-01" = { sku_name = "WS2" }
    }
    logic_apps = {
      "logic-a-ldo-uks-tst-01" = {
        service_plan_key = "asp-shared-ldo-uks-tst-01"

        create_storage_account     = false
        storage_account_name       = "stbrought"
        storage_account_access_key = "brought-key"

        identity = { type = "SystemAssigned" }

        connection_strings = [
          { name = "sql", type = "SQLAzure", value = "Server=..." }
        ]

        site_config = {
          always_on       = true
          min_tls_version = "1.3"
          cors = {
            allowed_origins = ["https://portal.azure.com"]
          }
        }
      }
    }
  }

  assert {
    condition     = azurerm_logic_app_standard.this["logic-a-ldo-uks-tst-01"].storage_account_name == "stbrought"
    error_message = "The brought storage account should be used."
  }

  assert {
    condition     = length(azurerm_storage_account.this) == 0
    error_message = "No storage account should be created when bringing your own."
  }

  assert {
    condition     = azurerm_logic_app_standard.this["logic-a-ldo-uks-tst-01"].identity[0].type == "SystemAssigned"
    error_message = "The identity should be attached."
  }
}

run "rejects_byo_storage_without_key" {
  command = plan

  variables {
    logic_apps = {
      "logic-bad-ldo-uks-tst-01" = {
        create_storage_account = false
        storage_account_name   = "stbrought"
      }
    }
  }

  expect_failures = [var.logic_apps]
}

run "rejects_two_plan_references" {
  command = plan

  variables {
    service_plans = { "asp-x-ldo-uks-tst-01" = {} }
    logic_apps = {
      "logic-bad-ldo-uks-tst-01" = {
        service_plan_key = "asp-x-ldo-uks-tst-01"
        service_plan_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-x/providers/Microsoft.Web/serverFarms/asp-y"
      }
    }
  }

  expect_failures = [var.logic_apps]
}

run "rejects_cors_wildcard_with_credentials" {
  command = plan

  variables {
    logic_apps = {
      "logic-bad-ldo-uks-tst-01" = {
        site_config = {
          cors = {
            allowed_origins     = ["*"]
            support_credentials = true
          }
        }
      }
    }
  }

  expect_failures = [var.logic_apps]
}
