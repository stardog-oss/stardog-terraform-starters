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

  target_groups_normalized = toset([for group in var.target_groups : lower(trimspace(group))])

  selected_students = {
    for k, v in local.infra_students : k => v
    if(
      length(var.target_students) == 0 || contains(var.target_students, k)
      ) && (
      length(local.target_groups_normalized) == 0 || contains(local.target_groups_normalized, lower(trimspace(try(v.group, ""))))
    )
  }

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

  launchpad_tls_secret_by_student = {
    for k in keys(local.selected_students) : k => "launchpad-${k}-training-tls"
  }

  sparql_tls_secret_by_student = {
    for k in keys(local.selected_students) : k => "sparql-${k}-training-tls"
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
    installer_rev    = "2026-06-05-kubectl-retry"
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
      legacySecretRef: $${ENVOY_TLS_SECRET}
      launchpadSecretRef: $${LAUNCHPAD_TLS_SECRET}
      sparqlSecretRef: $${SPARQL_TLS_SECRET}
  - name: bi-tcp
    port: 5806
    protocol: TCP
EOGW
    )
  }

  provisioner "local-exec" {
    interpreter = ["/usr/bin/env", "bash", "-c"]
    environment = {
      AKS_NAME             = each.value.aks_name
      AKS_RG               = each.value.resource_group_name
      KUBECONFIG_PATH      = local.kubeconfig_path_by_student[each.key]
      GATEWAY_NAMESPACE    = var.gateway_namespace
      GATEWAY_CLASS        = var.gateway_class_name
      GATEWAY_NAME         = local.envoy_gateway_name_by_student[each.key]
      ENVOY_PROXY_NAME     = local.envoy_proxy_name_by_student[each.key]
      ENVOY_TLS_SECRET     = local.envoy_tls_secret_by_student[each.key]
      LAUNCHPAD_TLS_SECRET = local.launchpad_tls_secret_by_student[each.key]
      SPARQL_TLS_SECRET    = local.sparql_tls_secret_by_student[each.key]
      PUBLIC_IP            = each.value.public_ip_address
      PUBLIC_IP_NAME       = each.value.public_ip_name
      PUBLIC_IP_RG         = each.value.resource_group_name
      CRDS_VERSION         = var.gateway_api_crds_version
      CM_CHART_VERSION     = var.cert_manager_chart_version
      EG_CHART_VERSION     = var.envoy_gateway_chart_version
      EG_RELEASE_NAME      = local.envoy_gateway_release_by_student[each.key]
    }
    command = <<-EOT
      set -euo pipefail

      mkdir -p "$(dirname "$KUBECONFIG_PATH")"
      az aks get-credentials -g "$AKS_RG" -n "$AKS_NAME" --file "$KUBECONFIG_PATH" --overwrite-existing >/dev/null
      export KUBECONFIG="$KUBECONFIG_PATH"

      kube() {
        local attempt
        for attempt in 1 2 3 4 5; do
          if kubectl --kubeconfig="$KUBECONFIG_PATH" "$@"; then
            return 0
          fi
          sleep $((attempt * 5))
        done
        kubectl --kubeconfig="$KUBECONFIG_PATH" "$@"
      }

      # The experimental bundle includes the standard Gateway API CRDs plus
      # TCPRoute/TLSRoute. Gateway API v1.5 blocks applying experimental CRDs
      # on top of standard CRDs through its safe-upgrade admission policy, so
      # remove the guard before upgrading an existing standard install.
      kube delete validatingadmissionpolicy safe-upgrades.gateway.networking.k8s.io --ignore-not-found >/dev/null
      kube delete validatingadmissionpolicybinding safe-upgrades.gateway.networking.k8s.io --ignore-not-found >/dev/null

      # Gateway API CRDs are too large for client-side apply's
      # kubectl.kubernetes.io/last-applied-configuration annotation.
      for crd in \
        gatewayclasses.gateway.networking.k8s.io \
        gateways.gateway.networking.k8s.io \
        grpcroutes.gateway.networking.k8s.io \
        httproutes.gateway.networking.k8s.io \
        referencegrants.gateway.networking.k8s.io \
        tcproutes.gateway.networking.k8s.io \
        tlsroutes.gateway.networking.k8s.io \
        udproutes.gateway.networking.k8s.io; do
        kube annotate crd "$crd" kubectl.kubernetes.io/last-applied-configuration- --overwrite >/dev/null 2>&1 || true
      done

      kube apply --server-side --force-conflicts -f "https://github.com/kubernetes-sigs/gateway-api/releases/download/$${CRDS_VERSION}/experimental-install.yaml" >/dev/null

      CM_VERSION_ARGS=""
      if [ -n "$CM_CHART_VERSION" ]; then
        CM_VERSION_ARGS="--version $${CM_CHART_VERSION}"
      fi

      if helm status cert-manager -n cert-manager >/dev/null 2>&1; then
        echo "cert-manager release exists; skipping cert-manager install/upgrade"
      else
        helm repo add --force-update jetstack https://charts.jetstack.io >/dev/null
        helm repo update jetstack >/dev/null

        helm upgrade --install cert-manager jetstack/cert-manager \
          --namespace cert-manager \
          --create-namespace \
          --set installCRDs=true \
          --set extraArgs[0]=--enable-gateway-api \
          $CM_VERSION_ARGS >/dev/null
      fi

      EG_VERSION_ARGS=""
      if [ -n "$EG_CHART_VERSION" ]; then
        EG_VERSION_ARGS="--version $${EG_CHART_VERSION}"
      fi

      helm show crds oci://docker.io/envoyproxy/gateway-helm $EG_VERSION_ARGS \
        | awk '
          /^---[[:space:]]*$/ {
            if (doc ~ /name: .*gateway\.envoyproxy\.io/) {
              print doc "---"
            }
            doc = ""
            next
          }
          { doc = doc $0 "\n" }
          END {
            if (doc ~ /name: .*gateway\.envoyproxy\.io/) {
              print doc
            }
          }
        ' \
        | kube apply --server-side --force-conflicts -f - >/dev/null

      helm upgrade --install "$EG_RELEASE_NAME" oci://docker.io/envoyproxy/gateway-helm \
        --namespace "$GATEWAY_NAMESPACE" \
        --create-namespace \
        --skip-crds \
        --set service.type=ClusterIP \
        --set deployment.replicas=2 \
        $EG_VERSION_ARGS >/dev/null

      kube -n "$GATEWAY_NAMESPACE" rollout restart deploy/envoy-gateway >/dev/null
      kube -n "$GATEWAY_NAMESPACE" rollout status deploy/envoy-gateway --timeout=5m >/dev/null

      cat <<EOF | kube apply -f - >/dev/null
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
          - kind: Secret
            name: $${LAUNCHPAD_TLS_SECRET}
          - kind: Secret
            name: $${SPARQL_TLS_SECRET}
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

      kube annotate gatewayclass "$GATEWAY_CLASS" training.sd/reconciled-at="$(date +%s)" --overwrite >/dev/null
      kube -n "$GATEWAY_NAMESPACE" annotate gateway "$GATEWAY_NAME" training.sd/reconciled-at="$(date +%s)" --overwrite >/dev/null
    EOT
  }
}
