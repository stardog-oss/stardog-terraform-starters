# Cert-Manager (Terraform + Helm)

This module installs **cert-manager** using Terraform’s Helm and Kubernetes providers.  
It supports:

- Classic Helm **repo** source **or** any **OCI** registry (ACR / ECR / GCP Artifact Registry / GHCR).
- Optional namespace creation.
- `installCRDs = true` by default (recommended).
- Freeform `extra_values` map merged last to override chart values.

---

## Quick Start — Public Helm Repo

**1) `envs/cert-manager/versions.tf`**

```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    kubernetes = { source = "hashicorp/kubernetes", version = ">= 2.21.0" }
    helm       = { source = "hashicorp/helm",       version = ">= 2.12.1" }
  }
}

provider "kubernetes" {
  config_path = var.kubeconfig_path
}

provider "helm" {
  kubernetes { config_path = var.kubeconfig_path }
}
```

**2) `envs/cert-manager/variables.tf`**

```hcl
variable "kubeconfig_path" { type = string }
```

**3) `envs/cert-manager/main.tf`**

```hcl
module "cert_manager" {
  source = "../../modules/kubernetes/cert_manager"

  # Namespace & chart source
  namespace      = "cert-manager"
  chart_source   = "repo"                          # "repo" or "oci"
  chart_repo_url = "https://charts.jetstack.io"
  chart_name     = "cert-manager"
  chart_version  = "v1.8.0"                        # pin as desired

  # Behavior
  create_namespace = true
  install_crds     = true

  # Optional overrides merged last
  # extra_values = {
  #   replicaCount = 2
  # }
}
```

**4) `envs/cert-manager/terraform.tfvars`**

```hcl
kubeconfig_path = "~/.kube/config"
```

**5) Deploy**

```bash
cd envs/cert-manager
terraform init -reconfigure
terraform plan -out tfplan
terraform apply tfplan
```

**6) Verify**

```bash
kubectl get ns cert-manager
kubectl -n cert-manager get deploy,po
kubectl -n cert-manager get crds | grep cert-manager
```

---

## Using an OCI Registry (ACR / ECR / GCP / GHCR)

Switch the module inputs to `chart_source = "oci"` and set an OCI URL + version (first push the chart to your registry).

**`envs/cert-manager/main.tf`**

```hcl
module "cert_manager" {
  source = "../../modules/kubernetes/cert_manager"

  namespace = "cert-manager"

  chart_source      = "oci"
  oci_chart_url     = "oci://sdprofileaacr.azurecr.io/helm/cert-manager" # ACR example
  oci_chart_version = "v1.8.0"

  create_namespace = true
  install_crds     = true
}
```

### Helm Provider Authentication (examples)

Pick one based on your registry. Use CI secrets / federated identity for credentials.

**Azure ACR**
```hcl
provider "helm" {
  kubernetes { config_path = var.kubeconfig_path }
  registry {
    url = "sdprofileaacr.azurecr.io"
    # username/password optional if docker creds or AAD auth is already configured
    # username = var.acr_username
    # password = var.acr_password
  }
}
```
Or pre-login via CLI:
```bash
az acr login -n sdprofileaacr
helm registry login sdprofileaacr.azurecr.io
```

**AWS ECR**
```hcl
provider "helm" {
  kubernetes { config_path = var.kubeconfig_path }
  registry {
    url      = "123456789012.dkr.ecr.us-east-1.amazonaws.com"
    username = "AWS"
    password = var.ecr_token  # from: aws ecr get-login-password
  }
}
```

**GCP Artifact Registry**
```hcl
provider "helm" {
  kubernetes { config_path = var.kubeconfig_path }
  registry {
    url      = "us-docker.pkg.dev"
    username = "_json_key"
    password = var.gcp_service_account_json  # raw JSON string
  }
}
```

> If your runner already has a valid `~/.docker/config.json`, Helm will reuse it and you can omit `registry {}`.

---

## Optional Features

### 1) Extra chart values
You can supply any Helm values in `extra_values` (merged last). For example, set replica count and resource limits:

```hcl
extra_values = {
  replicaCount = 2
  resources = {
    requests = { cpu = "100m", memory = "256Mi" }
    limits   = { cpu = "500m", memory = "512Mi" }
  }
}
```

### 2) Namespace management
Set `create_namespace = false` if you manage the `cert-manager` namespace elsewhere.

---

## Important Module Variables

| Name | Type | Default | Notes |
|------|------|---------|------|
| `namespace` | string | `"cert-manager"` | Install target namespace |
| `create_namespace` | bool | `true` | Create the namespace if needed |
| `install_crds` | bool | `true` | Sets `installCRDs=true` in values |
| `extra_values` | map(any) | `{}` | Freeform Helm values merged last |
| `chart_source` | string | `"repo"` | `"repo"` or `"oci"` |
| `chart_repo_url` | string | `https://charts.jetstack.io` | Used when `chart_source="repo"` |
| `chart_name` | string | `"cert-manager"` | Used when `chart_source="repo"` |
| `chart_version` | string\|null | `null` | Optional pin for repo charts (e.g., `v1.8.0`) |
| `oci_chart_url` | string\|null | `null` | Used when `chart_source="oci"` (e.g., `oci://…/cert-manager`) |
| `oci_chart_version` | string\|null | `null` | **Required** when `chart_source="oci"` |

### Outputs

| Name | Description |
|------|-------------|
| `namespace` | Namespace where cert-manager is installed |
| `release_name` | Helm release name |

---

## Troubleshooting

- **CRDs missing**: Ensure `install_crds = true`. If you previously installed cert-manager manually, remove stale CRDs or set the flag accordingly.
- **OCI 401/403**: Confirm Helm is logged into the registry, or configure the Helm provider `registry {}` block.
- **Webhook/leader-election issues**: Temporarily scale down conflicting releases; verify the namespace and service accounts exist.
- **Plan/apply diffs**: When switching between repo and OCI sources, consider destroying/recreating the Helm release to avoid drift.

---

## Uninstall

From your env folder:
```bash
terraform destroy
```

This removes the Helm release and, if `create_namespace = true` and nothing else remains in it, the namespace as well.
