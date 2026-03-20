# Azure Container Registry (ACR) – Terraform Module

This module creates an **Azure Container Registry (ACR)** and (optionally) grants **AcrPull** to one or more **AKS kubelet managed identities**.

Highlights:
- Strict name validation (5–50 lowercase alphanumeric).
- SKU selectable: **Basic**, **Standard**, **Premium**.
- Optional **admin user** enable/disable.
- Optional **role assignment** to AKS kubelet MI(s) via the `cluster` input map.
- Consistent **tags** applied to all resources.

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

> Configure authentication via Azure CLI login, Managed Identity, or environment variables as per the azurerm provider docs.

---

## Quick Start

**Root module**

```hcl
module "acr" {
  source              = "../../modules/azure/acr"

  resource_group_name = "myteam-rg"
  location            = "eastus"

  acr_name            = "myteamacr"     # 5–50 chars, lowercase a–z0–9
  acr_sku             = "Basic"         # Basic | Standard | Premium
  acr_admin_enabled   = true            # enable admin user (use with care)

  tags = {
    env   = "stage"
    owner = "platform"
  }
}
```

Outputs you’ll typically use later:

```hcl
output "acr_id"           { value = module.acr.id }
output "acr_name"         { value = module.acr.name }
output "acr_login_server" { value = module.acr.login_server }  # e.g., myteamacr.azurecr.io
```

Push/pull example:

```bash
az acr login -n myteamacr
docker tag app:latest myteamacr.azurecr.io/app:latest
docker push myteamacr.azurecr.io/app:latest
```

---

## Attach AKS (AcrPull) – Kubelet Managed Identity

If you provision AKS separately, pass its **kubelet managed identity object id** to this module to grant **AcrPull**:

```hcl
module "aks" {
  # your AKS module that exports kubelet_object_id
  # ...
}

module "acr" {
  source              = "../../modules/azure/acr"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  acr_name            = "myteamacr"

  # Supply one or more kubelet identities (map values)
  cluster = {
    default = {
      kubelet_object_id = module.aks.kubelet_object_id  # may be unknown at plan
    }
  }

  tags = var.tags
}
```

> The module uses a **plan-safe** pattern (boolean gating / static keys) so that the role assignment only runs when identities are provided and becomes valid at **apply** time.

---

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `resource_group_name` | `string` | n/a | Name of the Azure Resource Group where the ACR will be created. |
| `location` | `string` | n/a | Azure region for the ACR (e.g., `eastus`). |
| `cluster` | `map(object({ kubelet_object_id = optional(string) }))` | `null` | Optional map of AKS clusters keyed by any label; each may include `kubelet_object_id`. When provided, the module grants **AcrPull** to those principals. Set to `null` to skip. |
| `acr_name` | `string` | n/a | ACR name. **5–50** lowercase alphanumeric only (e.g., `myteamacr`). |
| `acr_sku` | `string` | `"Basic"` | ACR SKU: one of `Basic`, `Standard`, `Premium`. |
| `acr_admin_enabled` | `bool` | `true` | Enable the ACR admin user (username/password). Handy for dev; consider `false` for prod. |
| `manage_acr` | `bool` | `true` | `true` = Terraform creates/manages the registry. `false` = skip creation and use a data source to reference an existing ACR (read-only). |
| `tags` | `map(string)` | `{}` | Tags applied to all resources created by this module. |
| `source_registry_username` | `string` | `null` | Optional source registry username to use during `az acr import` (avoids anonymous pull rate limits). |
| `source_registry_password` | `string` | `null` | Optional source registry password/access token paired with `source_registry_username`. |

> The module adds plan-time validations to enforce `acr_name` format and `acr_sku` values.

---

## Outputs


| Name | Description |
|------|-------------|
| `id` | ARM resource ID of the ACR. |
| `name` | Name of the ACR. |
| `login_server` | FQDN for image references, e.g. `myteamacr.azurecr.io`. |

Example consumption:

```hcl
image = "${module.acr.login_server}/stardog/server:latest"

---

- **SKU**: `Basic` is cost-effective; `Standard` adds throughput/features; `Premium` offers geo-replication & private endpoints.

---

## Common Scenarios


---

## Optional: Import images from Docker Hub into the ACR (one-off)

This module provides an optional, opt-in helper that runs `az acr import` for a list
of images. It is intentionally disabled by default. The import runs as a local
provisioner (so it executes where you run `terraform apply`).

How to enable:

```hcl
module "acr" {
  source = "../../modules/azure/acr"
  # ...other required inputs...
  import_images     = true
  # optionally override the default images
  images_to_import = [
    "stardog/stardog:11.2.0",
    "stardog/launchpad:3.6.0",
    "stardog/voicebox-service:v0.22.0",
  ]
}
```

Notes:
- The `az` CLI must be installed and authenticated where Terraform runs (local machine or CI runner).
- For CI or Terraform Cloud remote runs, prefer running `az acr import` as a separate pipeline step (recommended) or ensure the remote executor has `az` and credentials.
- Provide `source_registry_username` and `source_registry_password` if you hit source registry anonymous pull limits (for example, Docker Hub); leave them unset for public, unauthenticated pulls.
- If an image includes a registry host (e.g., `stardog-example-helm-chart.jfrog.io/hello-world-app:latest`), the module uses that host for `az acr import`. When the host looks like JFrog, it will prefer `jfrog_registry_username`/`jfrog_registry_password` when provided.
- The import uses `--force` to overwrite existing tags; adjust the command in `import_images.tf` if you want different behavior.
### 1) ACR only (no AKS yet)
Just run the quick start. Later, wire AKS by adding the `cluster` map with the kubelet object id.

### 2) Multiple AKS clusters
Provide multiple entries in the `cluster` map (keys are arbitrary but should be stable if you expect updates in-place).

```hcl
cluster = {
  prod = { kubelet_object_id = module.aks_prod.kubelet_object_id }
  qa   = { kubelet_object_id = module.aks_qa.kubelet_object_id }
}
```

### 3) Attaching post-create
If the ACR already exists and you only need to add AcrPull, run this module with the same `acr_name` (or import the existing ACR) and set the `cluster` map—only the role assignment will be added.

---

## Using an Existing ACR (read-only)

Set `manage_acr = false` to skip registry creation and reference an existing ACR
via data source. Terraform remains read-only for the registry, but the helper
imports and role assignments still run:

```hcl
module "acr" {
  source              = "../../modules/azure/acr"
  resource_group_name = "rg-with-acrexist"
  location            = var.location
  manage_acr          = false

  acr_name = "acrexist"
  cluster  = { aks = { kubelet_object_id = module.aks.kubelet_object_id } }

  import_images    = true
  images_to_import = [
    "stardog/stardog:11.2.0",
    "stardog/launchpad:v3.6.0",
    "stardog/voicebox-service:v0.22.0",
  ]
}
```

---

## Importing an Existing ACR (optional)

If you prefer Terraform to manage the registry (so it enforces SKU, tags, etc.),
keep the default `manage_acr = true` and import the Azure resource into state:

```bash
terraform import module.acr.azurerm_container_registry.this[0] "/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RG>/providers/Microsoft.ContainerRegistry/registries/<acr_name>"
```

> Afterwards, run `terraform plan` to sync drift and let the module manage tags, admin flag, imports, and role assignments.

---

## Security Tips

- Prefer **Azure AD** or **Managed Identity** for CI/CD and AKS pulls rather than the ACR admin account.
- Use **`Premium`** SKU if you need **private endpoints**, **zone redundancy**, or **content trust** features.
- Tag everything consistently (env, owner, cost-center) to simplify lifecycle and clean-up.

---

## Destroy

```bash
terraform destroy
```

If other modules (e.g., AKS) are still referencing the ACR, remove those bindings first (role assignments, image pulls).
