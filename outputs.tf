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
  description = "Map of app name to a curated logic app object (name, id, kind, hostname, outbound IPs, custom domain verification id, and the SCM site_credential). Sensitive because it carries site_credential. The full resource object is deliberately not exported: doing so surfaces the provider-deprecated site_config.public_network_access_enabled attribute. The ids, hostnames, and identity maps alongside stay plain for composition."
  value = {
    for k, a in azurerm_logic_app_standard.this : k => {
      name                           = a.name
      id                             = a.id
      kind                           = a.kind
      default_hostname               = a.default_hostname
      custom_domain_verification_id  = a.custom_domain_verification_id
      outbound_ip_addresses          = a.outbound_ip_addresses
      possible_outbound_ip_addresses = a.possible_outbound_ip_addresses
      site_credential                = a.site_credential
    }
  }
  sensitive = true
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
