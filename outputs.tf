output "default_hostnames" {
  description = "Map of app name to default hostname."
  value       = { for k, a in azurerm_logic_app_standard.this : k => a.default_hostname }
}

output "identity_principal_ids" {
  description = "Map of app name to { system_assigned } principal id (null where absent)."
  value = {
    for k, a in azurerm_logic_app_standard.this : k => {
      system_assigned = try(a.identity[0].principal_id, null)
    }
  }
}

output "kind" {
  description = "Map of app name to the app kind."
  value       = { for k, a in azurerm_logic_app_standard.this : k => a.kind }
}

output "logic_app_ids" {
  description = "Map of app name to id."
  value       = { for k, a in azurerm_logic_app_standard.this : k => a.id }
}

output "logic_app_ids_zipmap" {
  description = "Map of app name to { name, id } for easy composition."
  value       = { for k, a in azurerm_logic_app_standard.this : k => { name = a.name, id = a.id } }
}

output "logic_apps" {
  description = "Map of app name to the full logic app object. Sensitive as a whole because it carries the storage access key and site credentials; the ids, hostnames, and identity maps alongside stay plain for composition."
  value       = azurerm_logic_app_standard.this
  sensitive   = true
}

output "service_plan_ids" {
  description = "Map of plan name (or app name for auto-created plans) to plan id."
  value = merge(
    { for k, p in azurerm_service_plan.this : k => p.id },
    { for k, p in azurerm_service_plan.auto : "asp-${k}" => p.id },
  )
}

output "storage_account_names" {
  description = "Map of app name to the module-created storage account name (only apps with create_storage_account)."
  value       = { for k, s in azurerm_storage_account.this : k => s.name }
}
