provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}

data "terraform_remote_state" "infra" {
  backend = "azurerm"

  config = {
    resource_group_name  = var.tfstate_resource_group_name
    storage_account_name = var.tfstate_storage_account_name
    container_name       = var.tfstate_container_name
    key                  = local.infra_state_key
    use_azuread_auth     = true
  }
}

locals {
  infra_state_key = var.infra_state_key != "" ? var.infra_state_key : "envs/${var.name_prefix}/terraform.tfstate"
  infra_students  = try(data.terraform_remote_state.infra.outputs.students, {})

  selected_students = length(var.target_students) > 0 ? {
    for k, v in local.infra_students : k => v if contains(var.target_students, k)
  } : local.infra_students

  common_tags = merge(var.tags, { name_prefix = var.name_prefix })

  kubeconfig_path_by_student = {
    for k in keys(local.selected_students) : k => "${var.infra_kubeconfig_dir}/${k}.yaml"
  }

  envoy_gateway_release_by_student = {
    for k in keys(local.selected_students) : k => "${k}-envoy-gateway"
  }

  envoy_gateway_name_by_student = {
    for k in keys(local.selected_students) : k => "${k}-envoy-gateway"
  }

  envoy_proxy_name_by_student = {
    for k in keys(local.selected_students) : k => "${k}-envoy-proxy"
  }

  envoy_tls_secret_by_student = {
    for k in keys(local.selected_students) : k => "${k}-envoy-tls"
  }
}

resource "null_resource" "envoy_gateway_install" {
  for_each = var.enable_gateway_install ? local.selected_students : {}

  triggers = {
    student          = each.key
    aks_name         = each.value.aks_name
    rg_name          = each.value.resource_group_name
    public_ip_name   = each.value.public_ip_name
    public_ip_addr   = each.value.public_ip_address
    crds_version     = var.gateway_api_crds_version
    cm_chart_version = var.cert_manager_chart_version
    eg_chart_version = var.envoy_gateway_chart_version
    gateway_spec_sha = sha1(<<-EOGW
listeners:
  - name: http
    port: 80
    protocol: HTTP
  - name: https
    port: 443
    protocol: HTTPS
    tls:
      mode: Terminate
      secretRef: $${ENVOY_TLS_SECRET}
  - name: bi-tcp
    port: 5806
    protocol: TCP
EOGW
    )
  }

  provisioner "local-exec" {
    interpreter = ["/usr/bin/env", "bash", "-c"]
    environment = {
      AKS_NAME           = each.value.aks_name
      AKS_RG             = each.value.resource_group_name
      KUBECONFIG_PATH    = local.kubeconfig_path_by_student[each.key]
      GATEWAY_NAMESPACE  = var.gateway_namespace
      GATEWAY_CLASS      = var.gateway_class_name
      GATEWAY_NAME       = local.envoy_gateway_name_by_student[each.key]
      ENVOY_PROXY_NAME   = local.envoy_proxy_name_by_student[each.key]
      ENVOY_TLS_SECRET   = local.envoy_tls_secret_by_student[each.key]
      PUBLIC_IP          = each.value.public_ip_address
      PUBLIC_IP_NAME     = each.value.public_ip_name
      PUBLIC_IP_RG       = each.value.resource_group_name
      CRDS_VERSION       = var.gateway_api_crds_version
      CM_CHART_VERSION   = var.cert_manager_chart_version
      EG_CHART_VERSION   = var.envoy_gateway_chart_version
      EG_RELEASE_NAME    = local.envoy_gateway_release_by_student[each.key]
    }
    command = <<-EOT
      set -euo pipefail

      mkdir -p "$(dirname "$KUBECONFIG_PATH")"
      az aks get-credentials -g "$AKS_RG" -n "$AKS_NAME" --file "$KUBECONFIG_PATH" --overwrite-existing >/dev/null
      export KUBECONFIG="$KUBECONFIG_PATH"

      kubectl --kubeconfig="$KUBECONFIG_PATH" apply -f "https://github.com/kubernetes-sigs/gateway-api/releases/download/$${CRDS_VERSION}/standard-install.yaml" >/dev/null
      kubectl --kubeconfig="$KUBECONFIG_PATH" apply -f "https://github.com/kubernetes-sigs/gateway-api/releases/download/$${CRDS_VERSION}/experimental-install.yaml" >/dev/null

      helm repo add jetstack https://charts.jetstack.io >/dev/null
      helm repo update >/dev/null

      CM_VERSION_ARGS=""
      if [ -n "$CM_CHART_VERSION" ]; then
        CM_VERSION_ARGS="--version $${CM_CHART_VERSION}"
      fi

      helm upgrade --install cert-manager jetstack/cert-manager \
        --namespace cert-manager \
        --create-namespace \
        --set installCRDs=true \
        --set extraArgs[0]=--enable-gateway-api \
        $CM_VERSION_ARGS >/dev/null

      EG_VERSION_ARGS=""
      if [ -n "$EG_CHART_VERSION" ]; then
        EG_VERSION_ARGS="--version $${EG_CHART_VERSION}"
      fi

      helm upgrade --install "$EG_RELEASE_NAME" oci://docker.io/envoyproxy/gateway-helm \
        --namespace "$GATEWAY_NAMESPACE" \
        --create-namespace \
        --set service.type=ClusterIP \
        --set deployment.replicas=2 \
        $EG_VERSION_ARGS >/dev/null

      cat <<EOF | kubectl --kubeconfig="$KUBECONFIG_PATH" apply -f - >/dev/null
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: EnvoyProxy
metadata:
  name: $${ENVOY_PROXY_NAME}
  namespace: $${GATEWAY_NAMESPACE}
spec:
  provider:
    type: Kubernetes
    kubernetes:
      envoyService:
        type: LoadBalancer
        loadBalancerIP: $${PUBLIC_IP}
        annotations:
          service.beta.kubernetes.io/azure-load-balancer-resource-group: $${PUBLIC_IP_RG}
          service.beta.kubernetes.io/azure-pip-name: $${PUBLIC_IP_NAME}
---
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: $${GATEWAY_CLASS}
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
  parametersRef:
    group: gateway.envoyproxy.io
    kind: EnvoyProxy
    name: $${ENVOY_PROXY_NAME}
    namespace: $${GATEWAY_NAMESPACE}
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: $${GATEWAY_NAME}
  namespace: $${GATEWAY_NAMESPACE}
spec:
  gatewayClassName: $${GATEWAY_CLASS}
  listeners:
    - name: http
      port: 80
      protocol: HTTP
      allowedRoutes:
        namespaces:
          from: All
    - name: https
      port: 443
      protocol: HTTPS
      tls:
        mode: Terminate
        certificateRefs:
          - kind: Secret
            name: $${ENVOY_TLS_SECRET}
      allowedRoutes:
        namespaces:
          from: All
    - name: bi-tcp
      port: 5806
      protocol: TCP
      allowedRoutes:
        namespaces:
          from: All
EOF
    EOT
  }
}
