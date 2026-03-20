resource "kubernetes_namespace_v1" "ngf" {
  metadata {
    name = var.namespace
  }
}

locals {
  nginx_gateway_service_block = merge(
    {
      annotations = var.nginx_gateway_service_annotations
      labels      = var.nginx_gateway_service_labels
    }
  )

  nginx_data_plane_service_block = merge(
    {
      type                 = var.nginx_data_plane_service_type
      externalTrafficPolicy = var.nginx_data_plane_external_traffic_policy
    },
    var.nginx_data_plane_load_balancer_ip != null && trimspace(var.nginx_data_plane_load_balancer_ip) != "" ? { loadBalancerIP = var.nginx_data_plane_load_balancer_ip } : {},
    length(var.nginx_data_plane_load_balancer_source_ranges) > 0 ? { loadBalancerSourceRanges = var.nginx_data_plane_load_balancer_source_ranges } : {},
    length(var.nginx_data_plane_service_annotations) > 0 ? { annotations = var.nginx_data_plane_service_annotations } : {},
    length(var.nginx_data_plane_service_labels) > 0 ? { labels = var.nginx_data_plane_service_labels } : {}
  )

  base_values = {
    nginxGateway = {
      gatewayClassName      = var.gateway_class_name
      gatewayControllerName = var.gateway_controller_name
      replicas              = var.nginx_gateway_replicas
      service               = local.nginx_gateway_service_block
    }
    nginx = {
      kind     = var.nginx_data_plane_kind
      replicas = var.nginx_data_plane_replicas
      service  = local.nginx_data_plane_service_block
    }
    gateways = var.gateways
  }

  merged_values = merge(local.base_values, var.extra_values)
  values_yaml   = yamlencode(local.merged_values)
}

resource "helm_release" "ngf" {
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

  depends_on = [kubernetes_namespace_v1.ngf]
}
