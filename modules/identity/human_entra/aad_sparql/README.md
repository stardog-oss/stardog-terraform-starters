# Azure AD Application (SPARQL) — Terraform Module

This module provisions a Microsoft Entra ID (Azure AD) **Application** and **Service Principal** for a SPARQL endpoint, wires **owners**, requests **Microsoft Graph** delegated permission **User.Read**, defines **app roles** (`reader`, `writer`, `admin`), generates a **client secret**, and stores that secret (and client id) via a pluggable **secret backend** (Azure Key Vault, AWS Secrets Manager, etc.). It also supports an optional **exact identifier URI** override.

---

## What it creates

- **Application** (`azuread_application.app`) with:
  - `sign_in_audience = AzureADMultipleOrgs`
  - `identifier_uris` are set post-creation via `azuread_application_identifier_uri` (defaults to `api://<clientId>`). You can pass `var.identifier_uri` to override.
  - Web platform: your `redirect_uris` and **implicit grant** for access & ID tokens
  - **OAuth2 permission scope** `user_login` (example scope with a stable GUID you control)
  - **App roles**: `reader`, `writer`, `admin` (each with stable GUIDs you control)
  - **Required resource access** for Microsoft Graph **User.Read** (delegated)
- **Service Principal** (`azuread_service_principal.sp`) for the app
- Owner assignments managed directly on the `azuread_application` resource using the union of the provided IDs and the Terraform operator.
- **Application password** (`azuread_application_password.pwd`) using a **random** secret and a **computed RFC3339 end date** (no deprecated fields)
- Two secret entries written through the [`modules/secret_store`](../../../secret_store) helper for the generated client secret and client id.

> The module keeps app‑role and scope GUIDs **stable** (hard‑coded) so downstream assignments remain valid across applies/environments.

---

## Requirements

```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azuread = { source = "hashicorp/azuread", version = ">= 2.44.0" }
    azurerm = { source = "hashicorp/azurerm", version = ">= 4.0.0" } # required when backend.kind = "azure_key_vault"
    aws     = { source = "hashicorp/aws",     version = ">= 5.0.0" } # required when backend.kind = "aws_secrets_manager"
    time    = { source = "hashicorp/time",    version = ">= 0.11.0" }
    random  = { source = "hashicorp/random",  version = ">= 3.5.0" }
  }
}

provider "azuread" {}
provider "azurerm" { features {} } # only when storing secrets in Azure Key Vault
provider "aws"     { region = "us-east-1" } # only when storing secrets in AWS Secrets Manager
```

**Permissions needed**
- The operator identity must be allowed to **create applications/service principals** (directory/app admin context).
- Ensure the operator identity can write to the chosen secret backend (Key Vault RBAC/access policy, Secrets Manager IAM permissions, etc.).

---

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `inst_id` | `string` | n/a | Short instance identifier used for names/labels (e.g., `profile-a`). |
| `display_name` | `string` | `null` | App display name. If `null`, you should compute a default from `inst_id` via a local (see below). |
| `identifier_uri` | `string` | `null` | Optional **exact** identifier URI to set (e.g., `api://<guid>` or a verified domain URI). If `null` the app uses a random `api://<uuid>` value only. |
| `redirect_uris` | `list(string)` | `[]` | Web redirect URIs for the app. |
| `owner_object_ids` | `list(string)` | `[]` | Entra **object** IDs (users or service principals) to assign as application owners. |
| `secret_backend` | `object` | n/a | Backend configuration describing where to persist secrets (e.g., Azure Key Vault or AWS Secrets Manager). |

**Recommended local for display name**
```hcl
locals {
  effective_display_name = coalesce(var.display_name, "${var.inst_id} - SPARQL")
}
```

Use `local.effective_display_name` when setting `azuread_application.app.display_name`.

---

## Usage (minimal)

### Azure Key Vault example

```hcl
locals {
  secret_backend = {
    kind   = "azure_key_vault"
    config = { key_vault_id = module.akv.id }
  }
}

module "aad_sparql" {
  source = "../../modules/identity/human_entra/aad_sparql"

  inst_id          = "profile-a"
  redirect_uris    = [
    "http://localhost:49998",
    "https://launchpad.profile-a.example.com/auth/sso-connection"
  ]
  owner_object_ids = ["4bce3531-c720-41f0-acb8-b93ba6fa0182"]
  secret_backend   = local.secret_backend

  # Optional: set a precise identifier URI (must be unique globally)
  identifier_uri   = null
}
```

### AWS Secrets Manager example

```hcl
locals {
  secret_backend = {
    kind   = "aws_secrets_manager"
    config = { secret_arn = module.secretvault.arn }
  }
}

module "aad_sparql" {
  source = "../../modules/identity/human_entra/aad_sparql"

  inst_id          = "profile-a"
  redirect_uris    = [
    "http://localhost:49998",
    "https://launchpad.profile-a.example.com/auth/sso-connection"
  ]
  owner_object_ids = ["4bce3531-c720-41f0-acb8-b93ba6fa0182"]
  secret_backend   = local.secret_backend
}
```

After apply, retrieve credentials from your configured backend (Key Vault secret, Secrets Manager version, etc.) using the deterministic secret names (`aad-<display>-client-secret`, `aad-<display>-client-id`).

---

## Outputs (suggested)

Add outputs in your module for easy reuse downstream:
```hcl
output "application_id" { value = azuread_application.app.application_id }
output "client_id"      { value = azuread_application.app.client_id }
output "sp_object_id"   { value = azuread_service_principal.sp.id }
```

Mark sensitive outputs if needed. Secret material should be retrieved from your secret backend instead of module outputs.

---

## Notes on GUIDs, roles & scopes

- The **Microsoft Graph** application id is well‑known: `00000003-0000-0000-c000-000000000000` (used here via `local.graph_app_id`).
- The **User.Read** delegated scope GUID (`e1fe6dd8-ba31-4d61-89e7-88639da4683d`) is stable and reused tenant‑wide.
- Your app’s **roles** (`reader`, `writer`, `admin`) and the example **oauth2 scope** (`user_login`) use **stable GUIDs** you control. These must be **unique within the app**; keeping them constant is recommended so external assignments don’t break.
- If you need to change a role/scope: add a **new** one with a new GUID, migrate assignments, then remove the old one.

---

## Identifier URI behavior

By default, the app gets an identifier set to `api://<clientId>` via the `azuread_application_identifier_uri` resource. You can still supply `var.identifier_uri` to override this behavior.
- If you want a custom, deterministic identifier (e.g., `api://profile-a-sparql` or `api://sparql.example.com`), set `var.identifier_uri` → the module’s `azuread_application_identifier_uri.exact` will apply it.

> Identifier URIs must be **unique tenant‑wide** and, for domain‑based URIs, the domain must be **verified** in your tenant.

---

## Secret handling and rotation

- The client secret value is created via `random_password` and set on the app via `azuread_application_password` with a computed **`end_date`** (no deprecated `end_date_relative`).
- The **same value** is written to your configured secret backend so you can retrieve it later (Graph never returns it again).
- For **rotation**, either taint `random_password.secret` or use `time_rotating` + `keepers` to rotate on a schedule—your backend will store a new **version** automatically (Key Vault, Secrets Manager, etc.).

**Security**
- The plaintext secret appears in **Terraform state**. Use a **remote backend**, restrict access, and avoid echoing it in outputs/logs.

---

## Troubleshooting

- **“Required attribute not specified” / HCL parse errors**: ensure nested blocks (like `resource_access`) are written over multiple lines, with `id` and `type` on separate lines.
- **“Identifier URI already in use”**: choose a unique identifier; for domain URIs ensure the domain is verified.
- **Secret backend writes fail**: ensure the operator has sufficient permissions (Key Vault RBAC/access policy, Secrets Manager IAM rights, etc.).
-- **Owners not added**: verify you passed **user or service principal object IDs**, not display names or group IDs. Azure AD does not accept groups as application owners.

---

## See Also
- [Shared Launchpad/SPARQL stack](../shared_stack/README.md) - bundle both app registrations and secret wiring in one module.
- [Launchpad application module](../aad_launchpad/README.md) - sibling registration geared toward the Stardog Launchpad UI.
- [App role assignment helper](../app_role_assignment/README.md) - use with this module's exported role IDs to grant access to principals.

---

## Complete example (inline)

```hcl
provider "azuread" {}
provider "azurerm" { features {} }

data "azuread_client_config" "current" {}

locals {
  graph_app_id           = "00000003-0000-0000-c000-000000000000"
  user_read_id           = "e1fe6dd8-ba31-4d61-89e7-88639da4683d"
  effective_display_name = coalesce(var.display_name, "${var.inst_id} - SPARQL")
  owner_object_ids       = distinct(length(var.owner_object_ids) > 0 ? concat(var.owner_object_ids, [data.azuread_client_config.current.object_id]) : [data.azuread_client_config.current.object_id])
}

resource "azuread_application" "app" {
  display_name                   = local.effective_display_name
  sign_in_audience               = "AzureADMultipleOrgs"
  # identifier_uris is set separately via azuread_application_identifier_uri.primary
  fallback_public_client_enabled = true

  owners = local.owner_object_ids

  api {
    requested_access_token_version = 2
    oauth2_permission_scope {
      admin_consent_display_name = "user_login"
      admin_consent_description  = "user_login"
      user_consent_display_name  = "user_login"
      user_consent_description   = "user_login"
      enabled = true
      type    = "User"
      value   = "user_login"
      id      = "b318d0d6-d13e-461b-b22b-46d9ac3459b6"
    }
  }

  app_role {
    allowed_member_types = ["User","Application"]
    description          = "reader"
    display_name         = "reader"
    enabled              = true
    id                   = "8797249a-1696-4ccf-85f7-d7b2a5ef514e"
    value                = "reader"
  }
  app_role {
    allowed_member_types = ["Application"]
    description          = "writer"
    display_name         = "writer"
    enabled              = true
    id                   = "3955cf75-ad5a-4e69-b08c-ad5d4798e732"
    value                = "writer"
  }
  app_role {
    allowed_member_types = ["User","Application"]
    description          = "admin"
    display_name         = "admin"
    enabled              = true
    id                   = "97932c93-52c2-4561-a7a7-7fea2443c6d7"
    value                = "admin"
  }

  web {
    redirect_uris = var.redirect_uris
    implicit_grant {
      access_token_issuance_enabled = true
      id_token_issuance_enabled     = true
    }
  }

  public_client { redirect_uris = ["http://localhost:443"] }

  required_resource_access {
    resource_app_id = local.graph_app_id
    resource_access {
      id   = local.user_read_id
      type = "Scope"
    }
  }
}

resource "azuread_service_principal" "sp" {
  client_id = azuread_application.app.client_id
}

resource "time_static" "app_pwd_start" {}
locals {
  app_password_ttl = "8760h" # 1 year
  app_password_end = timeadd(time_static.app_pwd_start.rfc3339, local.app_password_ttl)
  secret_name_base = replace(lower(local.effective_display_name), " ", "-")
  secret_entries = {
    "aad-${local.secret_name_base}-client-secret" = {
      value        = random_password.secret.result
      content_type = "application/x-azuread-client-secret"
    }
    "aad-${local.secret_name_base}-client-id" = {
      value        = azuread_application.app.client_id
      content_type = "text/plain"
    }
  }
}

resource "random_password" "secret" {
  length  = 32
  special = true
}

resource "azuread_application_password" "pwd" {
  application_id = azuread_application.app.id
  display_name   = var.inst_id
  value          = random_password.secret.result
  end_date       = local.app_password_end
}

module "secret_store" {
  source = "../../secret_store"

  backend = var.secret_backend
  entries = local.secret_entries

  depends_on = [azuread_application_password.pwd]
}

resource "azuread_application_identifier_uri" "exact" {
  count          = var.identifier_uri == null || var.identifier_uri == "" ? 0 : 1
  application_id = azuread_application.app.id
  identifier_uri = var.identifier_uri
}
```

---

Happy querying! 🔍
