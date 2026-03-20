# Azure Resource Group

Creates or references an Azure Resource Group with optional deletion lock support.

## Features
- Toggle between creating a new resource group or reusing an existing one.
- Optional `CanNotDelete` management lock for created groups.
- Validates the location of reused resource groups to prevent drift.

## Inputs
| Name | Type | Default | Description |
|------|------|---------|-------------|
| `name` | `string` | n/a | Resource group name. |
| `location` | `string` | n/a | Azure region (also used to validate existing RGs). |
| `create` | `bool` | `true` | Create the resource group when `true`; otherwise data source lookup. |
| `tags` | `map(string)` | `{}` | Tags applied when creating the resource group. |
| `lock` | `bool` | `false` | Add a `CanNotDelete` lock (only when `create = true`). |

## Outputs
| Name | Description |
|------|-------------|
| `id` | Resource group ID. |
| `name` | Resource group name. |
| `location` | Resource group location. |

## Example
```hcl
module "rg" {
  source   = "../../modules/azure/rg"
  name     = "rg-apps-eastus"
  location = "eastus"
  tags     = { environment = "dev" }
  lock     = true
}
```
