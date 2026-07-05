<!--
  Keep the title and badges OUTSIDE the centered <div>: the Terraform Registry's markdown renderer
  does not parse markdown inside an HTML block, so a # heading or [![badge]] in the div renders as
  literal text on the registry. Only the logo (HTML) goes in the div.
-->
<div align="center">
  <a href="https://libredevops.org">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://libredevops.org/assets/libre-devops-white.png">
      <img alt="Libre DevOps" src="https://libredevops.org/assets/libre-devops-black.png" width="300">
    </picture>
  </a>
</div>

# Terraform Azure Logic App Standard

Terraform module for Azure Logic App Standard, in the Libre DevOps style: fast to get going,
secure by default, flexible when it matters. A Logic App Standard is a Functions-host app under
the hood, so this module is built on everything the linux/windows function app modules learned.

[![CI](https://github.com/libre-devops/terraform-azurerm-logic-app-standard/actions/workflows/ci.yml/badge.svg)](https://github.com/libre-devops/terraform-azurerm-logic-app-standard/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/libre-devops/terraform-azurerm-logic-app-standard?sort=semver&label=release)](https://github.com/libre-devops/terraform-azurerm-logic-app-standard/releases/latest)
[![Terraform Registry](https://img.shields.io/badge/registry-libre--devops-7B42BC?logo=terraform&logoColor=white)](https://registry.terraform.io/namespaces/libre-devops)
[![License](https://img.shields.io/github/license/libre-devops/terraform-azurerm-logic-app-standard)](./LICENSE)

---

## Overview

```hcl
module "logic_app_standard" {
  source  = "libre-devops/logic-app-standard/azurerm"
  version = "~> 4.0"

  resource_group_id = module.rg.ids["rg-ldo-uks-dev-001"]
  location          = "uksouth"
  tags              = module.tags.tags

  logic_apps = {
    "logic-ldo-uks-dev-001" = {}
  }
}
```

That single entry gets a dedicated WS1 (Workflow Standard) plan, a storage account, and secure
defaults the provider does not give you: `https_only`, and FTP and SCM basic-auth publishing OFF.
Every default has an explicit override.

- **Apps as a map, plans as a map.** Multiple apps share a plan via `service_plan_key`,
  `service_plan_id` brings your own, `app_service_environment_id` places a plan on an ASE, and an
  app that references no plan gets its own WS1 automatically.
- **Storage, keys-on by design.** Unlike a keyless function app, Logic App Standard requires a
  storage account name AND access key, so the module creates a keys-on account (TLS 1.2 floor,
  infrastructure encryption) and feeds its key, or takes a bring-your-own name and key (a
  validation makes sure you provide both).
- **The full site_config.** always_on, the elastic scale knobs (app_scale_limit,
  pre_warmed_instance_count, elastic_instance_minimum), the .NET and Linux runtime versions, TLS
  floors, health check, CORS, and IP restrictions (with their forwarded-header matchers) on both
  the app and the SCM site.
- **Identity, connection strings, and VNet.** System or user assigned identity,
  key_vault_reference_identity_id, connection strings, virtual_network_subnet_id, and
  vnet_content_share_enabled are all exposed, plus the extension bundle and Functions runtime
  version.

## Examples

- [`examples/minimal`](./examples/minimal) - one Logic App Standard on a dedicated plan, applied
  and destroyed in CI.
- [`examples/complete`](./examples/complete) - a shared plan hosting an app with a system-assigned
  identity, Application Insights wired through app settings, always_on, a TLS 1.3 floor, CORS, and
  a connection string.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0, < 2.0.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.0.0, < 5.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | 4.80.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_logic_app_standard.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/logic_app_standard) | resource |
| [azurerm_service_plan.auto](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/service_plan) | resource |
| [azurerm_service_plan.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/service_plan) | resource |
| [azurerm_storage_account.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_location"></a> [location](#input\_location) | Azure region for all resources in this module. | `string` | n/a | yes |
| <a name="input_logic_apps"></a> [logic\_apps](#input\_logic\_apps) | Logic App Standard apps keyed by name. A Logic App Standard is a Functions-host app under the<br/>hood, so this module mirrors the function app modules: fast to get going (an entry with just a<br/>name gets a dedicated plan and a storage account), flexible when it matters (the full<br/>site\_config, connection strings, identity, and VNet surface).<br/><br/>PLAN: exactly one of service\_plan\_key (a plan from service\_plans), service\_plan\_id (bring your<br/>own), or neither (a dedicated WS1 workflow-standard plan is created).<br/><br/>STORAGE: unlike a keyless function app, a Logic App Standard requires a storage account name<br/>and ACCESS KEY, so storage is keys-on. create\_storage\_account (default) builds one with secure<br/>defaults and feeds its key; or bring your own with storage\_account\_name + storage\_account\_access\_key.<br/><br/>SECURE DEFAULTS overriding the provider's: https\_only true, ftp\_publish\_basic\_authentication\_enabled<br/>and scm\_publish\_basic\_authentication\_enabled false. version defaults to ~4 (the Functions<br/>runtime) and the WS1 plan is workflow-standard. | <pre>map(object({<br/>    service_plan_key = optional(string)<br/>    service_plan_id  = optional(string)<br/><br/>    # Storage (keys-on; created by default).<br/>    create_storage_account                    = optional(bool, true)<br/>    storage_account_name                      = optional(string)<br/>    storage_account_access_key                = optional(string)<br/>    storage_account_replication_type          = optional(string, "LRS")<br/>    storage_infrastructure_encryption_enabled = optional(bool, true)<br/><br/>    # Runtime.<br/>    version              = optional(string, "~4")<br/>    use_extension_bundle = optional(bool)<br/>    bundle_version       = optional(string)<br/><br/>    # Identity.<br/>    identity = optional(object({<br/>      type         = string<br/>      identity_ids = optional(list(string))<br/>    }))<br/>    key_vault_reference_identity_id = optional(string)<br/><br/>    # Security and networking.<br/>    https_only                               = optional(bool, true)<br/>    client_certificate_mode                  = optional(string)<br/>    ftp_publish_basic_authentication_enabled = optional(bool, false)<br/>    scm_publish_basic_authentication_enabled = optional(bool, false)<br/>    virtual_network_subnet_id                = optional(string)<br/>    vnet_content_share_enabled               = optional(bool)<br/>    enabled                                  = optional(bool, true)<br/><br/>    # Settings.<br/>    app_settings = optional(map(string), {})<br/>    connection_strings = optional(list(object({<br/>      name  = string<br/>      type  = string<br/>      value = string<br/>    })), [])<br/><br/>    site_config = optional(object({<br/>      always_on                         = optional(bool)<br/>      app_scale_limit                   = optional(number)<br/>      dotnet_framework_version          = optional(string)<br/>      elastic_instance_minimum          = optional(number)<br/>      ftps_state                        = optional(string)<br/>      health_check_path                 = optional(string)<br/>      http2_enabled                     = optional(bool)<br/>      ip_restriction_default_action     = optional(string)<br/>      linux_fx_version                  = optional(string)<br/>      min_tls_version                   = optional(string)<br/>      pre_warmed_instance_count         = optional(number)<br/>      public_network_access_enabled     = optional(bool)<br/>      runtime_scale_monitoring_enabled  = optional(bool)<br/>      scm_ip_restriction_default_action = optional(string)<br/>      scm_min_tls_version               = optional(string)<br/>      scm_type                          = optional(string)<br/>      scm_use_main_ip_restriction       = optional(bool)<br/>      use_32_bit_worker_process         = optional(bool)<br/>      vnet_route_all_enabled            = optional(bool)<br/>      websockets_enabled                = optional(bool)<br/><br/>      cors = optional(object({<br/>        allowed_origins     = optional(list(string))<br/>        support_credentials = optional(bool)<br/>      }))<br/><br/>      ip_restrictions = optional(list(object({<br/>        action                    = optional(string)<br/>        description               = optional(string)<br/>        ip_address                = optional(string)<br/>        name                      = optional(string)<br/>        priority                  = optional(number)<br/>        service_tag               = optional(string)<br/>        virtual_network_subnet_id = optional(string)<br/>        headers = optional(list(object({<br/>          x_azure_fdid      = optional(list(string))<br/>          x_fd_health_probe = optional(list(string))<br/>          x_forwarded_for   = optional(list(string))<br/>          x_forwarded_host  = optional(list(string))<br/>        })))<br/>      })), [])<br/><br/>      scm_ip_restrictions = optional(list(object({<br/>        action                    = optional(string)<br/>        description               = optional(string)<br/>        ip_address                = optional(string)<br/>        name                      = optional(string)<br/>        priority                  = optional(number)<br/>        service_tag               = optional(string)<br/>        virtual_network_subnet_id = optional(string)<br/>        headers = optional(list(object({<br/>          x_azure_fdid      = optional(list(string))<br/>          x_fd_health_probe = optional(list(string))<br/>          x_forwarded_for   = optional(list(string))<br/>          x_forwarded_host  = optional(list(string))<br/>        })))<br/>      })), [])<br/>    }), {})<br/><br/>    tags = optional(map(string))<br/>  }))</pre> | `{}` | no |
| <a name="input_resource_group_id"></a> [resource\_group\_id](#input\_resource\_group\_id) | Id of the resource group the apps live in; the module parses the name from it. | `string` | n/a | yes |
| <a name="input_service_plans"></a> [service\_plans](#input\_service\_plans) | App service plans keyed by name, shareable by multiple apps via service\_plan\_key. sku\_name<br/>defaults to WS1 (Workflow Standard). Apps that reference no plan get their own WS1 plan. | <pre>map(object({<br/>    os_type                      = optional(string, "Windows")<br/>    sku_name                     = optional(string, "WS1")<br/>    app_service_environment_id   = optional(string)<br/>    maximum_elastic_worker_count = optional(number)<br/>    zone_balancing_enabled       = optional(bool)<br/>    tags                         = optional(map(string))<br/>  }))</pre> | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to all resources; per-app and per-plan tags override these. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_default_hostnames"></a> [default\_hostnames](#output\_default\_hostnames) | Map of app name to default hostname. |
| <a name="output_identity_principal_ids"></a> [identity\_principal\_ids](#output\_identity\_principal\_ids) | Map of app name to { system\_assigned } principal id (null where absent). |
| <a name="output_kind"></a> [kind](#output\_kind) | Map of app name to the app kind. |
| <a name="output_logic_app_ids"></a> [logic\_app\_ids](#output\_logic\_app\_ids) | Map of app name to id. |
| <a name="output_logic_app_ids_zipmap"></a> [logic\_app\_ids\_zipmap](#output\_logic\_app\_ids\_zipmap) | Map of app name to { name, id } for easy composition. |
| <a name="output_logic_apps"></a> [logic\_apps](#output\_logic\_apps) | Map of app name to a curated logic app object (name, id, kind, hostname, outbound IPs, custom domain verification id, and the SCM site\_credential). Sensitive because it carries site\_credential. The full resource object is deliberately not exported: doing so surfaces the provider-deprecated site\_config.public\_network\_access\_enabled attribute. The ids, hostnames, and identity maps alongside stay plain for composition. |
| <a name="output_service_plan_ids"></a> [service\_plan\_ids](#output\_service\_plan\_ids) | Map of plan name (or app name for auto-created plans) to plan id. |
| <a name="output_storage_account_names"></a> [storage\_account\_names](#output\_storage\_account\_names) | Map of app name to the module-created storage account name (only apps with create\_storage\_account). |
<!-- END_TF_DOCS -->
