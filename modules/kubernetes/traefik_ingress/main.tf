resource "kubernetes_namespace_v1" "traefik" {
  metadata {
    name = var.namespace
  }
}

locals {
  base_values = {
    deployment = {
      replicas = var.replica_count
    }
    service = {
      enabled     = true
      type        = var.service_type
      annotations = var.service_annotations
      ports = {
        web = [
          {
            port       = 80
            targetPort = 8000
            protocol   = "TCP"
          }
        ]
        websecure = [
          {
            port       = 443
            targetPort = 8443
            protocol   = "TCP"
          }
        ]
      }
    }
    experimental = {
      kubernetesGateway = {
        enabled = false
      }
    }
    providers = {
      kubernetesGateway = {
        enabled = true
      }
    }
    gateway = {
      enabled = false
    }
    gatewayClass = {
      enabled = true
      name    = "traefik"
    }
  }

  merged_values = merge(local.base_values, var.extra_values)
  values_yaml   = yamlencode(local.merged_values)
  kubeconfig_path_resolved = replace(pathexpand(var.kubeconfig_path), "\\", "/")
}

resource "null_resource" "gateway_api_crds" {
  triggers = {
    enabled      = tostring(var.install_gateway_api_crds)
    experimental = tostring(var.install_gateway_api_experimental_crds)
    version      = var.gateway_api_crds_version
    kubeconfig   = local.kubeconfig_path_resolved
  }

  provisioner "local-exec" {
    interpreter = var.shell_interpreter
    command     = <<-EOT
      set -euo pipefail
      if [ "${var.install_gateway_api_crds}" != "true" ]; then
        echo "Gateway API CRD installation disabled; skipping"
        exit 0
      fi
      AKS_RG="${var.aks_resource_group_name}"
      AKS_NAME="${var.aks_cluster_name}"
      KCFG_PATH="${local.kubeconfig_path_resolved}"
      if az aks show -g "$${AKS_RG}" -n "$${AKS_NAME}" >/dev/null 2>&1; then
        mkdir -p "$(dirname "$${KCFG_PATH}")"
        az aks get-credentials -g "$${AKS_RG}" -n "$${AKS_NAME}" --file "$${KCFG_PATH}" --overwrite-existing >/dev/null
      else
        echo "AKS cluster $${AKS_NAME} not available; skipping kubeconfig refresh" >&2
        exit 1
      fi
      kubectl --kubeconfig="$${KCFG_PATH}" apply -f "https://github.com/kubernetes-sigs/gateway-api/releases/download/${var.gateway_api_crds_version}/standard-install.yaml"
      if [ "${var.install_gateway_api_experimental_crds}" = "true" ]; then
        kubectl --kubeconfig="$${KCFG_PATH}" apply -f "https://github.com/kubernetes-sigs/gateway-api/releases/download/${var.gateway_api_crds_version}/experimental-install.yaml"
      fi
    EOT
  }
}

resource "helm_release" "traefik_repo" {
  count            = var.chart_source == "repo" ? 1 : 0
  name             = "traefik"
  repository       = var.chart_repo_url
  chart            = var.chart_name
  namespace        = var.namespace
  version          = var.chart_version != "" ? var.chart_version : null
  values           = [local.values_yaml]
  create_namespace = false
  depends_on = [kubernetes_namespace_v1.traefik, null_resource.gateway_api_crds]
}

resource "helm_release" "traefik_oci" {
  count            = var.chart_source == "oci" ? 1 : 0
  name             = "traefik"
  chart            = var.oci_chart_url
  namespace        = var.namespace
  version          = var.oci_chart_version
  values           = [local.values_yaml]
  create_namespace = false
  depends_on = [kubernetes_namespace_v1.traefik, null_resource.gateway_api_crds]

  lifecycle {
    precondition {
      condition     = var.oci_chart_url != null && var.oci_chart_version != null
      error_message = "When chart_source = \"oci\", set both oci_chart_url and oci_chart_version."
    }
  }
}
