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
