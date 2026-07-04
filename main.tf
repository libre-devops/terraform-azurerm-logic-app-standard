locals {
  rg = provider::azurerm::parse_resource_id(var.resource_group_id)

  # Apps that reference no plan get their own dedicated WS1 (workflow standard) plan.
  auto_plan_apps = { for k, a in var.logic_apps : k => a if a.service_plan_key == null && a.service_plan_id == null }

  storage_create_apps = { for k, a in var.logic_apps : k => a if a.create_storage_account }

  # st<flattened app key>, trimmed to the 24-char storage limit.
  storage_account_names = {
    for k, a in local.storage_create_apps : k => coalesce(
      a.storage_account_name,
      substr("st${replace(replace(lower(k), "-", ""), "_", "")}", 0, 24),
    )
  }

  # Logic App Standard needs a storage account name and access key: the created account's, or the
  # caller's brought pair.
  host_storage = {
    for k, a in var.logic_apps : k => (
      a.create_storage_account ? {
        name = azurerm_storage_account.this[k].name
        key  = azurerm_storage_account.this[k].primary_access_key
        } : {
        name = a.storage_account_name
        key  = a.storage_account_access_key
      }
    )
  }
}

resource "azurerm_service_plan" "this" {
  for_each = var.service_plans

  resource_group_name = local.rg.resource_group_name
  location            = var.location
  tags                = merge(var.tags, coalesce(each.value.tags, {}))

  name                         = each.key
  os_type                      = each.value.os_type
  sku_name                     = each.value.sku_name
  app_service_environment_id   = each.value.app_service_environment_id
  maximum_elastic_worker_count = each.value.maximum_elastic_worker_count
  zone_balancing_enabled       = each.value.zone_balancing_enabled
}

# Dedicated WS1 plans for apps that reference no plan.
resource "azurerm_service_plan" "auto" {
  for_each = local.auto_plan_apps

  resource_group_name = local.rg.resource_group_name
  location            = var.location
  tags                = merge(var.tags, coalesce(each.value.tags, {}))

  name     = "asp-${each.key}"
  os_type  = "Windows"
  sku_name = "WS1"
}

# Keys-on storage: Logic App Standard requires the account key, so shared keys stay enabled.
resource "azurerm_storage_account" "this" {
  for_each = local.storage_create_apps

  resource_group_name = local.rg.resource_group_name
  location            = var.location
  tags                = merge(var.tags, coalesce(each.value.tags, {}))

  name                              = local.storage_account_names[each.key]
  account_tier                      = "Standard"
  account_replication_type          = each.value.storage_account_replication_type
  min_tls_version                   = "TLS1_2"
  https_traffic_only_enabled        = true
  allow_nested_items_to_be_public   = false
  infrastructure_encryption_enabled = each.value.storage_infrastructure_encryption_enabled
}

resource "azurerm_logic_app_standard" "this" {
  for_each = var.logic_apps

  resource_group_name = local.rg.resource_group_name
  location            = var.location
  tags                = merge(var.tags, coalesce(each.value.tags, {}))

  name = each.key
  app_service_plan_id = coalesce(
    each.value.service_plan_id,
    each.value.service_plan_key != null ? azurerm_service_plan.this[coalesce(each.value.service_plan_key, "-")].id : null,
    try(azurerm_service_plan.auto[each.key].id, null),
  )

  storage_account_name       = local.host_storage[each.key].name
  storage_account_access_key = local.host_storage[each.key].key

  version                                  = each.value.version
  use_extension_bundle                     = each.value.use_extension_bundle
  bundle_version                           = each.value.bundle_version
  https_only                               = each.value.https_only
  client_certificate_mode                  = each.value.client_certificate_mode
  ftp_publish_basic_authentication_enabled = each.value.ftp_publish_basic_authentication_enabled
  scm_publish_basic_authentication_enabled = each.value.scm_publish_basic_authentication_enabled
  key_vault_reference_identity_id          = each.value.key_vault_reference_identity_id
  virtual_network_subnet_id                = each.value.virtual_network_subnet_id
  vnet_content_share_enabled               = each.value.vnet_content_share_enabled
  enabled                                  = each.value.enabled

  app_settings = each.value.app_settings

  dynamic "identity" {
    for_each = each.value.identity != null ? [each.value.identity] : []

    content {
      type         = identity.value.type
      identity_ids = identity.value.identity_ids
    }
  }

  dynamic "connection_string" {
    for_each = each.value.connection_strings

    content {
      name  = connection_string.value.name
      type  = connection_string.value.type
      value = connection_string.value.value
    }
  }

  site_config {
    always_on                         = each.value.site_config.always_on
    app_scale_limit                   = each.value.site_config.app_scale_limit
    dotnet_framework_version          = each.value.site_config.dotnet_framework_version
    elastic_instance_minimum          = each.value.site_config.elastic_instance_minimum
    ftps_state                        = each.value.site_config.ftps_state
    health_check_path                 = each.value.site_config.health_check_path
    http2_enabled                     = each.value.site_config.http2_enabled
    ip_restriction_default_action     = each.value.site_config.ip_restriction_default_action
    linux_fx_version                  = each.value.site_config.linux_fx_version
    min_tls_version                   = each.value.site_config.min_tls_version
    pre_warmed_instance_count         = each.value.site_config.pre_warmed_instance_count
    public_network_access_enabled     = each.value.site_config.public_network_access_enabled
    runtime_scale_monitoring_enabled  = each.value.site_config.runtime_scale_monitoring_enabled
    scm_ip_restriction_default_action = each.value.site_config.scm_ip_restriction_default_action
    scm_min_tls_version               = each.value.site_config.scm_min_tls_version
    scm_type                          = each.value.site_config.scm_type
    scm_use_main_ip_restriction       = each.value.site_config.scm_use_main_ip_restriction
    use_32_bit_worker_process         = each.value.site_config.use_32_bit_worker_process
    vnet_route_all_enabled            = each.value.site_config.vnet_route_all_enabled
    websockets_enabled                = each.value.site_config.websockets_enabled

    dynamic "cors" {
      for_each = each.value.site_config.cors != null ? [each.value.site_config.cors] : []

      content {
        allowed_origins     = cors.value.allowed_origins
        support_credentials = cors.value.support_credentials
      }
    }

    dynamic "ip_restriction" {
      for_each = each.value.site_config.ip_restrictions

      content {
        action                    = ip_restriction.value.action
        description               = ip_restriction.value.description
        ip_address                = ip_restriction.value.ip_address
        name                      = ip_restriction.value.name
        priority                  = ip_restriction.value.priority
        service_tag               = ip_restriction.value.service_tag
        virtual_network_subnet_id = ip_restriction.value.virtual_network_subnet_id
        headers                   = ip_restriction.value.headers
      }
    }

    dynamic "scm_ip_restriction" {
      for_each = each.value.site_config.scm_ip_restrictions

      content {
        action                    = scm_ip_restriction.value.action
        description               = scm_ip_restriction.value.description
        ip_address                = scm_ip_restriction.value.ip_address
        name                      = scm_ip_restriction.value.name
        priority                  = scm_ip_restriction.value.priority
        service_tag               = scm_ip_restriction.value.service_tag
        virtual_network_subnet_id = scm_ip_restriction.value.virtual_network_subnet_id
        headers                   = scm_ip_restriction.value.headers
      }
    }
  }
}
