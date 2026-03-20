resource "kubernetes_namespace_v1" "ingress" {
  metadata {
    name = var.namespace
    labels = var.label_disable_cert_manager_validation ? {
      "cert-manager.io/disable-validation" = "true"
    } : null
  }
}

locals {
  controller_tcp_ports = var.enable_bi_port ? [
    {
      name       = "bi-port-${var.bi_port}"
      port       = var.bi_port
      targetPort = var.bi_port
      protocol   = "tcp"
    }
  ] : []

  controller_service = {
    type = var.service_type
    annotations = {
      "service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path" = var.health_probe_path
    }
    ports = {
      tcp = local.controller_tcp_ports
    }
  }

  tcp_services = var.enable_bi_port ? {
    "${var.bi_port}" = "${var.stardog_namespace}/${var.stardog_release}-stardog:${var.bi_port}"
  } : {}

  base_values = {
    controller = {
      replicaCount = var.replica_count
      publishService = {
        enabled = true
      }
      service = local.controller_service
      admissionWebhooks = {
        enabled = var.disable_admission_webhook ? false : true
      }
    }
    tcp = local.tcp_services
  }

  merged_values = merge(local.base_values, var.extra_values)
  values_yaml   = yamlencode(local.merged_values)
}

resource "helm_release" "ingress_repo" {
  count            = var.chart_source == "repo" ? 1 : 0
  name             = "ingress-nginx"
  repository       = var.chart_repo_url
  chart            = var.chart_name
  namespace        = var.namespace
  version          = var.chart_version
  values           = [local.values_yaml]
  create_namespace = false
  depends_on       = [kubernetes_namespace_v1.ingress]
}

resource "helm_release" "ingress_oci" {
  count            = var.chart_source == "oci" ? 1 : 0
  name             = "ingress-nginx"
  chart            = var.oci_chart_url
  namespace        = var.namespace
  version          = var.oci_chart_version
  values           = [local.values_yaml]
  create_namespace = false
  depends_on       = [kubernetes_namespace_v1.ingress]

  lifecycle {
    precondition {
      condition     = var.oci_chart_url != null && var.oci_chart_version != null
      error_message = "When chart_source = \"oci\", set both oci_chart_url and oci_chart_version."
    }
  }
}
