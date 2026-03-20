# Azure AD App Role Assignment — Terraform Module

This module assigns an **app role** exposed by a **resource service principal** (e.g., Microsoft Graph or your own application) to a **principal** (user, group, service principal, or managed identity).

It is a thin wrapper over:

```hcl
provider "azuread" {}

resource "azuread_app_role_assignment" "this" {
  app_role_id         = var.app_role_id
  principal_object_id = var.principal_object_id
  resource_object_id  = var.resource_sp_object_id
}
```

---

## Requirements

```hcl
terraform {
  required_version = ">= 1.4.0"
  required_providers {
    azuread = { source = "hashicorp/azuread", version = ">= 2.44.0" }
  }
}

provider "azuread" {}
```

> The identity running Terraform must have sufficient Microsoft Graph permissions to create **app role assignments** in your tenant (e.g., directory/application admin contexts).

---

## Inputs

| Name | Type | Description |
|------|------|-------------|
| `principal_object_id` | `string` | Object ID (GUID) of the **principal** receiving the role (user, group, service principal, or managed identity). |
| `resource_sp_object_id` | `string` | Object ID (GUID) of the **resource service principal** that **exposes** the role (e.g., Microsoft Graph SP, or your app’s SP). |
| `app_role_id` | `string` | GUID of the **app role** on the resource SP to assign (the role’s `id`, not its name/value). |

No outputs by default; add one if you want to expose `azuread_app_role_assignment.this.id`.

---

## Usage

### 1) Assign a Microsoft Graph role to a service principal

```hcl
# Look up Microsoft Graph service principal by well-known application ID
data "azuread_service_principal" "graph" {
  application_id = "00000003-0000-0000-c000-000000000000"
}

# Pick a role by its 'value' (example: Application.Read.All) and ensure it's assignable to "Application"
locals {
  graph_role_name = "Application.Read.All"
  graph_app_role_id = one([
    for r in data.azuread_service_principal.graph.app_roles :
    r.id if r.value == local.graph_role_name && contains(r.allowed_member_types, "Application")
  ])
}

# The principal receiving the role
data "azuread_service_principal" "my_app" {
  # replace with your app's client/application ID or object ID
  application_id = "11111111-2222-3333-4444-555555555555"
}

module "graph_role_assignment" {
  source = "../../modules/identity/aad_app_role_assignment"

  principal_object_id   = data.azuread_service_principal.my_app.id
  resource_sp_object_id = data.azuread_service_principal.graph.id
  app_role_id           = local.graph_app_role_id
}
```

### 2) Assign a custom app role from **your** application

```hcl
# Suppose you've created your application and its service principal elsewhere
data "azuread_service_principal" "resource" {
  # by application_id for your app
  application_id = azuread_application.app.application_id
}

# Choose the app role by its 'value' (e.g., "admin")
locals {
  role_value       = "admin"
  resource_role_id = one([
    for r in data.azuread_service_principal.resource.app_roles :
    r.id if r.value == local.role_value
  ])
}

# Principal (user/group/SP) who should receive the role
data "azuread_user" "ops" {
  user_principal_name = "ops-team@contoso.com"
}

module "custom_role_assignment" {
  source = "../../modules/identity/aad_app_role_assignment"

  principal_object_id   = data.azuread_user.ops.id
  resource_sp_object_id = data.azuread_service_principal.resource.id
  app_role_id           = local.resource_role_id
}
```

> **Tip:** You can target **groups** too (look up via `azuread_group`), which will grant the role to all members of that group.

---

## Common pitfalls & fixes

- **“Principal or resource not found”**: Ensure you’re using **object IDs** (SP/user/group objectId), not application (client) IDs—except when using data sources that translate `application_id` into a SP.
- **“Role already assigned”**: If the assignment exists outside Terraform, **import** it:
  ```bash
  terraform import module.graph_role_assignment.azuread_app_role_assignment.this     '<principal_object_id>/<resource_sp_object_id>/<app_role_id>'
  ```
- **Wrong role picked**: App roles have both a **`value`** (string) and an **`id`** (GUID). The resource needs the **GUID**. Use the `one([...])` trick shown above to select by `value` and extract the `id`.
- **Permissions**: Your operator identity must be allowed to create app role assignments (tenant policy & Graph permissions).

---

## Testing locally

```bash
terraform init
terraform validate
terraform plan -var='principal_object_id=<GUID>'                -var='resource_sp_object_id=<GUID>'                -var='app_role_id=<GUID>'
```

---

## Notes

- `resource_object_id` must be the **service principal’s objectId** (not the application ID). For Microsoft Graph you get it via `data.azuread_service_principal.graph.id`.
- If you manage **role definitions** (app roles) for your own app in Terraform, keep their **GUIDs stable** across environments to avoid breaking downstream assignments.

## See Also
- [SPARQL application module](../aad_sparql/README.md) - exposes the custom app roles this helper can assign.
- [Launchpad application module](../aad_launchpad/README.md) - pair this with role assignment to delegate access if needed.
- [Shared Launchpad/SPARQL stack](../shared_stack/README.md) - provisioning wrapper that already wires role assignments for the SPARQL admin group.
