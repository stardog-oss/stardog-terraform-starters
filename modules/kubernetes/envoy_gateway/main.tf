resource "kubernetes_namespace_v1" "envoy_gateway" {
  metadata {
    name = var.namespace
  }
}

locals {
  merged_values = merge(var.values, var.extra_values)
  values_yaml   = yamlencode(local.merged_values)
}

resource "helm_release" "envoy_gateway" {
  name       = var.release_name
  namespace  = var.namespace
  chart      = var.chart_url
  version    = var.chart_version != "" ? var.chart_version : null
  values     = [local.values_yaml]
  create_namespace = false

  atomic          = var.helm_atomic
  cleanup_on_fail = var.helm_cleanup_on_fail
  force_update    = var.helm_force_update
  timeout         = var.helm_timeout
  wait            = var.helm_wait

  depends_on = [kubernetes_namespace_v1.envoy_gateway]
}
