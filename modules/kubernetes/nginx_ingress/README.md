# NGINX Ingress (Terraform + Helm)

This module installs the **ingress-nginx** controller using Terraform’s Helm and Kubernetes providers.
It supports:
- Classic Helm **repo** source **or** any **OCI** registry (ACR / ECR / GCP Artifact Registry / GHCR).
- Namespace creation, Azure LB health-probe annotation.
- Optional Stardog **BI port (5806)** TCP exposure.
- Optional Cert-Manager validation label on the namespace.
- Freeform `extra_values` map merged last to override chart values.

## Quick Start — Public Helm Repo

**1) `envs/nginx-ingress/versions.tf`**

```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    kubernetes = { source = "hashicorp/kubernetes", version = ">= 2.21.0" }
    helm       = { source = "hashicorp/helm",       version = ">= 2.12.1" }
  }
}

provider "kubernetes" { config_path = var.kubeconfig_path }

provider "helm" {
  kubernetes { config_path = var.kubeconfig_path }
}
```

**2) `envs/nginx-ingress/variables.tf`**

```hcl
variable "kubeconfig_path"   { type = string }
variable "stardog_namespace" { type = string, default = null }
variable "stardog_release"   { type = string, default = null }
```

**3) `envs/nginx-ingress/main.tf`**

```hcl
module "nginx_ingress" {
  source            = "../../modules/kubernetes/nginx_ingress"
  namespace         = "ingress-objects"
  replica_count     = 2
  health_probe_path = "/healthz"

  # Optional: expose Stardog BI TCP 5806
  enable_bi_port    = var.stardog_namespace != null && var.stardog_release != null
  stardog_namespace = var.stardog_namespace
  stardog_release   = var.stardog_release
  bi_port           = 5806

  # Public Helm repo (default)
  chart_source   = "repo"
  chart_repo_url = "https://kubernetes.github.io/ingress-nginx"
  chart_name     = "ingress-nginx"
  # chart_version  = "4.11.2" # optional pin
}
```

**4) `envs/nginx-ingress/terraform.tfvars`**

```hcl
kubeconfig_path = "~/.kube/config"

# Optional for BI TCP 5806 mapping:
# stardog_namespace = "stardog"
# stardog_release   = "stardog"
```

**5) Deploy**

```bash
cd envs/nginx-ingress
terraform init -reconfigure
terraform plan -out tfplan
terraform apply tfplan
```

**6) Verify**

```bash
kubectl get ns ingress-objects
kubectl -n ingress-objects get deploy,po
kubectl -n ingress-objects get svc ingress-nginx-controller
kubectl -n ingress-objects get svc ingress-nginx-controller -o jsonpath='{.metadata.annotations.service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path}'; echo
```

> External IPs on the Service can take a few minutes to appear, depending on the cloud controller & LB.

---

## Using an OCI Registry (ACR / ECR / GCP / GHCR)

**Switch the module inputs** to use `chart_source = "oci"` and provide a fully-qualified OCI URL + version.

**`envs/nginx-ingress/main.tf`**

```hcl
module "nginx_ingress" {
  source            = "../../modules/kubernetes/nginx_ingress"
  namespace         = "ingress-objects"

  chart_source      = "oci"
  oci_chart_url     = "oci://sdprofileaacr.azurecr.io/helm/ingress-nginx" # ACR example
  oci_chart_version = "4.11.2"

  # (rest of your inputs: replica_count, BI settings, etc.)
}
```

### Helm Provider Authentication (examples)

Pick one based on your registry. Replace secrets with CI-managed variables.

**Azure ACR**
```hcl
provider "helm" {
  kubernetes { config_path = var.kubeconfig_path }
  registry {
    url = "sdprofileaacr.azurecr.io"
    # username/password optional if docker creds or AAD are already set up
    # username = var.acr_username
    # password = var.acr_password
  }
}
```
Or CLI before `terraform apply`:
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
    password = var.gcp_service_account_json  # raw JSON string (use CI secret)
  }
}
```

> If your runner already has a valid `~/.docker/config.json`, Helm will usually reuse it and you can omit `registry {}`.

---

## Optional Features

### 1) Stardog BI TCP port (5806)
Expose a TCP port for Stardog BI via the ingress controller Service:

```hcl
enable_bi_port    = true
stardog_namespace = "stardog"
stardog_release   = "stardog"
bi_port           = 5806
```

This config adds an extra Service port and a `tcp` mapping to the chart values so the controller forwards traffic to `<stardog_release>-stardog.<stardog_namespace>.svc` on `:5806`.

### 2) Internal Load Balancer (AKS example)
Override chart values using `extra_values` (merged last):
```hcl
extra_values = {
  controller = {
    service = {
      annotations = {
        "service.beta.kubernetes.io/azure-load-balancer-internal" = "true"
      }
    }
  }
}
```

### 3) Cert-Manager interplay
By default the namespace is labeled `cert-manager.io/disable-validation=true` and admission webhooks are disabled in the chart to avoid common conflicts. Flip these with:
```hcl
label_disable_cert_manager_validation = false
disable_admission_webhook             = false
```

---

## Important Module Variables

| Name | Type | Default | Notes |
|------|------|---------|------|
| `namespace` | string | `ingress-objects` | Where controller is installed |
| `replica_count` | number | `2` | Deployment replicas |
| `health_probe_path` | string | `/healthz` | Azure LB probe path |
| `enable_bi_port` | bool | `false` | Enables TCP port on Service |
| `bi_port` | number | `5806` | TCP port number |
| `stardog_namespace` | string\|null | `null` | Required if `enable_bi_port=true` |
| `stardog_release` | string\|null | `null` | Required if `enable_bi_port=true` |
| `extra_values` | map(any) | `{}` | Freeform Helm values (override last) |
| `chart_source` | string | `"repo"` | `"repo"` or `"oci"` |
| `chart_repo_url` | string | Ingress repo URL | Used when `chart_source="repo"` |
| `chart_name` | string | `"ingress-nginx"` | Used when `chart_source="repo"` |
| `chart_version` | string\|null | `null` | Optional pin for repo charts |
| `oci_chart_url` | string\|null | `null` | Used when `chart_source="oci"` |
| `oci_chart_version` | string\|null | `null` | **Required** when `chart_source="oci"` |

---

## Troubleshooting

- **No external IP**: Allow time for the cloud LB to provision. Confirm the Service is `LoadBalancer` and check the cloud controller manager logs.
- **OCI 401/403**: Make sure Helm is logged into your registry (see examples) or supply a `registry {}` block in the Helm provider.
- **Admission webhook issues**: Set `disable_admission_webhook = true` or tune cert-manager/webhook ordering.
- **Plan/apply diffs**: If you switched sources (repo ↔ OCI), run `terraform state rm helm_release.ingress_*` or just `terraform destroy` the release before redeploying.

---

## Uninstall

From your env folder:
```bash
terraform destroy
```

This removes the Helm release and namespace (if created only for this purpose).
