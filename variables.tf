variable "location" {
  description = "Azure region for all resources in this module."
  type        = string
}

variable "logic_apps" {
  description = <<-DESC
    Logic App Standard apps keyed by name. A Logic App Standard is a Functions-host app under the
    hood, so this module mirrors the function app modules: fast to get going (an entry with just a
    name gets a dedicated plan and a storage account), flexible when it matters (the full
    site_config, connection strings, identity, and VNet surface).

    PLAN: exactly one of service_plan_key (a plan from service_plans), service_plan_id (bring your
    own), or neither (a dedicated WS1 workflow-standard plan is created).

    STORAGE: unlike a keyless function app, a Logic App Standard requires a storage account name
    and ACCESS KEY, so storage is keys-on. create_storage_account (default) builds one with secure
    defaults and feeds its key; or bring your own with storage_account_name + storage_account_access_key.

    SECURE DEFAULTS overriding the provider's: https_only true, ftp_publish_basic_authentication_enabled
    and scm_publish_basic_authentication_enabled false. version defaults to ~4 (the Functions
    runtime) and the WS1 plan is workflow-standard.
  DESC
  type = map(object({
    service_plan_key = optional(string)
    service_plan_id  = optional(string)

    # Storage (keys-on; created by default).
    create_storage_account                    = optional(bool, true)
    storage_account_name                      = optional(string)
    storage_account_access_key                = optional(string)
    storage_account_replication_type          = optional(string, "LRS")
    storage_infrastructure_encryption_enabled = optional(bool, true)

    # Runtime.
    version              = optional(string, "~4")
    use_extension_bundle = optional(bool)
    bundle_version       = optional(string)

    # Identity.
    identity = optional(object({
      type         = string
      identity_ids = optional(list(string))
    }))
    key_vault_reference_identity_id = optional(string)

    # Security and networking.
    https_only                               = optional(bool, true)
    client_certificate_mode                  = optional(string)
    ftp_publish_basic_authentication_enabled = optional(bool, false)
    scm_publish_basic_authentication_enabled = optional(bool, false)
    virtual_network_subnet_id                = optional(string)
    vnet_content_share_enabled               = optional(bool)
    enabled                                  = optional(bool, true)

    # Settings.
    app_settings = optional(map(string), {})
    connection_strings = optional(list(object({
      name  = string
      type  = string
      value = string
    })), [])

    site_config = optional(object({
      always_on                         = optional(bool)
      app_scale_limit                   = optional(number)
      dotnet_framework_version          = optional(string)
      elastic_instance_minimum          = optional(number)
      ftps_state                        = optional(string)
      health_check_path                 = optional(string)
      http2_enabled                     = optional(bool)
      ip_restriction_default_action     = optional(string)
      linux_fx_version                  = optional(string)
      min_tls_version                   = optional(string)
      pre_warmed_instance_count         = optional(number)
      public_network_access_enabled     = optional(bool)
      runtime_scale_monitoring_enabled  = optional(bool)
      scm_ip_restriction_default_action = optional(string)
      scm_min_tls_version               = optional(string)
      scm_type                          = optional(string)
      scm_use_main_ip_restriction       = optional(bool)
      use_32_bit_worker_process         = optional(bool)
      vnet_route_all_enabled            = optional(bool)
      websockets_enabled                = optional(bool)

      cors = optional(object({
        allowed_origins     = optional(list(string))
        support_credentials = optional(bool)
      }))

      ip_restrictions = optional(list(object({
        action                    = optional(string)
        description               = optional(string)
        ip_address                = optional(string)
        name                      = optional(string)
        priority                  = optional(number)
        service_tag               = optional(string)
        virtual_network_subnet_id = optional(string)
        headers = optional(list(object({
          x_azure_fdid      = optional(list(string))
          x_fd_health_probe = optional(list(string))
          x_forwarded_for   = optional(list(string))
          x_forwarded_host  = optional(list(string))
        })))
      })), [])

      scm_ip_restrictions = optional(list(object({
        action                    = optional(string)
        description               = optional(string)
        ip_address                = optional(string)
        name                      = optional(string)
        priority                  = optional(number)
        service_tag               = optional(string)
        virtual_network_subnet_id = optional(string)
        headers = optional(list(object({
          x_azure_fdid      = optional(list(string))
          x_fd_health_probe = optional(list(string))
          x_forwarded_for   = optional(list(string))
          x_forwarded_host  = optional(list(string))
        })))
      })), [])
    }), {})

    tags = optional(map(string))
  }))
  default = {}

  validation {
    condition = alltrue([
      for a in values(var.logic_apps) :
      length([for v in [a.service_plan_key, a.service_plan_id] : v if v != null]) <= 1
    ])
    error_message = "Set at most one of service_plan_key or service_plan_id per app (neither creates a dedicated WS1 plan)."
  }

  validation {
    condition = alltrue([
      for a in values(var.logic_apps) :
      a.create_storage_account || (a.storage_account_name != null && a.storage_account_access_key != null)
    ])
    error_message = "When create_storage_account = false, provide both storage_account_name and storage_account_access_key (Logic App Standard needs the key)."
  }

  validation {
    condition = alltrue([
      for a in values(var.logic_apps) :
      try(a.site_config.cors, null) == null ? true : !(coalesce(a.site_config.cors.support_credentials, false) && contains(coalesce(a.site_config.cors.allowed_origins, []), "*"))
    ])
    error_message = "CORS cannot combine support_credentials = true with a wildcard allowed origin."
  }
}

variable "resource_group_id" {
  description = "Id of the resource group the apps live in; the module parses the name from it."
  type        = string
}

variable "service_plans" {
  description = <<-DESC
    App service plans keyed by name, shareable by multiple apps via service_plan_key. sku_name
    defaults to WS1 (Workflow Standard). Apps that reference no plan get their own WS1 plan.
  DESC
  type = map(object({
    os_type                      = optional(string, "Windows")
    sku_name                     = optional(string, "WS1")
    app_service_environment_id   = optional(string)
    maximum_elastic_worker_count = optional(number)
    zone_balancing_enabled       = optional(bool)
    tags                         = optional(map(string))
  }))
  default = {}
}

variable "tags" {
  description = "Tags applied to all resources; per-app and per-plan tags override these."
  type        = map(string)
  default     = {}
}
