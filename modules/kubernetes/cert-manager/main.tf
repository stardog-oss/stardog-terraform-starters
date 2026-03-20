# Optionally create the namespace first (idempotent)
resource "kubernetes_namespace_v1" "cm" {
  count = var.create_namespace ? 1 : 0
  metadata { name = var.namespace }
}

/* inlined values to avoid local usage */

# Install from Jetstack repo (public)
resource "helm_release" "cert_manager_repo" {
  count      = var.chart_source == "repo" ? 1 : 0
  name       = "cert-manager"
  repository = var.chart_repo_url
  chart      = var.chart_name
  namespace  = var.namespace

  # You can set this to "v1.8.0" to match the doc
  version    = var.chart_version

  values           = [yamlencode(merge({ installCRDs = var.install_crds }, var.extra_values))]
  create_namespace = false
  # ensure ns exists first if we're managing it
  depends_on       = [kubernetes_namespace_v1.cm]
}

# Install from OCI registry (ACR, ECR, GAR, GHCR, etc.)
resource "helm_release" "cert_manager_oci" {
  count     = var.chart_source == "oci" ? 1 : 0
  name      = "cert-manager"
  chart     = var.oci_chart_url
  namespace = var.namespace

  # OCI charts require explicit version (tag)
  version   = var.oci_chart_version
  values           = [yamlencode(merge({ installCRDs = var.install_crds }, var.extra_values))]
  create_namespace = false
  depends_on       = [kubernetes_namespace_v1.cm]

  lifecycle {
    precondition {
      condition     = var.oci_chart_url != null && var.oci_chart_version != null
      error_message = "When chart_source = \"oci\", set both oci_chart_url and oci_chart_version."
    }
  }
}
