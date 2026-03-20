# Azure Key Vault (AKV) — Terraform Module

This module creates an **Azure Key Vault** and lets you choose between the modern **RBAC data‑plane authorization** model (recommended) or the legacy **access policies** model for secret/key/certificate access.

It also supports:
- Supplying an **admin group** (for RBAC role assignment).
- Optional **tenant override** (cross‑tenant testing).
- Consistent **tags**.

---

## Requirements

```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = ">= 4.0.0" }
  }
}

provider "azurerm" {
  features {}
}
```

Authenticate using Azure CLI, Managed Identity, or environment variables as per the azurerm provider docs.

---

## Quick Start (RBAC — recommended)

```hcl
module "akv" {
  source = "../../modules/azure/akv"

  resource_group_name        = "platform-rg"
  location                   = "eastus"
  name                       = "platform-secrets-kv"

  # RBAC data-plane auth:
  rbac_authorization_enabled = true
  use_access_policies        = false

  # Optional: grant Key Vault Secrets Officer to a group
  admin_group_object_id = "00000000-0000-0000-0000-000000000001"

  # Optional: tag everything
  tags = { env = "stage", owner = "platform" }
}
```

Grant RBAC to a group or identity **outside** the module (example):
```hcl
resource "azurerm_role_assignment" "kv_secrets_reader" {
  scope                = module.akv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.app_group_object_id  # a group, user, or managed identity
}
```

> In RBAC mode, **do not** rely on access policies; use role assignments like **Key Vault Secrets User/Officer/Administrator** at the vault scope (or narrower).

---

## Access Policies Mode (legacy / when RBAC is not an option)

```hcl
module "akv" {
  source = "../../modules/azure/akv"

  resource_group_name        = "platform-rg"
  location                   = "eastus"
  name                       = "platform-secrets-kv"

  rbac_authorization_enabled = false
  use_access_policies        = true

  # Provide bootstrap principals when using access policies:
  tenant_id        = data.azurerm_client_config.current.tenant_id
  admin_object_id  = data.azurerm_client_config.current.object_id

  tags = { env = "stage", owner = "platform" }
}
```

> In access‑policy mode, the module configures a policy for `admin_object_id` to allow data‑plane access (secrets/keys/certs). Use only if RBAC cannot be used.

---

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `resource_group_name` | `string` | `null` | Name of the Resource Group that will contain the Key Vault. Set to `null` to accept a value from the parent module. |
| `location` | `string` | n/a | Azure region for the Key Vault (e.g., `eastus`). |
| `name` | `string` | `null` | Key Vault name (globally unique). Follow AKV naming rules (3–24 chars; alphanumeric and `-`). Lowercase recommended. |
| `tags` | `map(string)` | `{}` | Tags applied to the Key Vault resource. |
| `admin_group_object_id` | `string` | `null` | Microsoft Entra ID (AAD) **group** object ID to administer the vault via RBAC. |
| `rbac_authorization_enabled` | `bool` | `true` | Enable **RBAC data‑plane authorization** (recommended). When `true`, use RBAC roles for secrets/keys access instead of access policies. |
| `use_access_policies` | `bool` | `false` | Use **classic access policies** for data‑plane access. Set `true` only if RBAC cannot be used. |
| `tenant_id` | `string` | `null` | (Optional) Tenant ID to associate with the Key Vault. Defaults to current provider tenant when `null`. Useful for cross‑tenant tests. |
| `admin_object_id` | `string` | `null` | (Optional) Object ID of a **user or service principal** to grant admin access. Used for access policies when enabled; also grants Key Vault Secrets Officer in RBAC mode. |

---

## Outputs (adjust to match your `outputs.tf`)

Typical outputs for a Key Vault module are:

```hcl
output "id"        { value = azurerm_key_vault.this.id }
output "name"      { value = azurerm_key_vault.this.name }
output "vault_uri" { value = azurerm_key_vault.this.vault_uri }
```

You can then reference them elsewhere:
```hcl
data "azurerm_key_vault" "kv" {
  name                = module.akv.name
  resource_group_name = var.resource_group_name
}
```

---

## Common Patterns

**Cross‑tenant testing**
```hcl
module "akv" {
  # ...
  tenant_id = "11111111-2222-3333-4444-555555555555"
}
```

**RBAC role examples (data‑plane)**
- Key Vault Secrets User — read secrets
- Key Vault Secrets Officer — read/write secrets
- Key Vault Administrator — full management over keys/secrets/certs

**Access‑policy tips**
- Only use when RBAC isn’t available.
- Ensure `tenant_id` and `admin_object_id`/`admin_group_object_id` are correct object IDs (not app IDs).

---

## Destroy

```bash
terraform destroy
```

If other stacks or services still reference secrets, rotate or remove those references before destroying the vault.
