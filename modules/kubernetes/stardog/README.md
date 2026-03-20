# Stardog Helm module

Installs the Stardog Helm chart into Kubernetes using the `helm_release` resource.

Overview
- The module accepts a single chart address (`chart_url`) which may be an OCI URL (oci://...) or an HTTP/HTTPS chart archive/repo address.
- Deep value merges are delegated to Helm. Provide a `values_file` (path) or `values_yaml` (string) and runtime overrides via `helm_set` (list of name/value pairs) which are forwarded to the Helm release.
- When installing from a private OCI registry, the module will attempt a `helm registry login` prior to the Helm install if `chart_username`/`chart_password` are provided and `chart_url` starts with `oci://`.
- The module creates the Stardog license Kubernetes Secret using the provided base64 payload to avoid double-encoding.

Inputs
- `namespace` - Kubernetes namespace to install into.
- `values_yaml` - optional raw values.yaml content (string).
- `values_file` - optional path to a values.yaml file (string). If provided, the file will be passed to the Helm release.
- `chart_url` - OCI or HTTPS chart URL (e.g. `oci://registry.example.com/charts/stardog` or `https://example.com/stardog-1.2.3.tgz`).
- `chart_version` - optional chart/version pin used by `helm_release` when applicable.
- `chart_username`, `chart_password` - credentials used for `helm registry login` when `chart_url` is an OCI URL.
- `helm_set` - optional list(object) of Helm set entries (each element: { name = "path.to.value", value = "..." }). These are passed directly to the Helm provider as `set` so Helm performs the merge.
- `cachetarget_enabled` - when true and `auto_configure_resources` is enabled, the module mirrors the auto-derived CPU/memory and JVM heap/direct memory settings onto `cachetarget.*` values in addition to the primary Stardog server.
- `auto_configure_resources` - when true (default), the module inspects Kubernetes node allocatable resources, subtracts the current requests from `kube-system` workloads on those nodes (with an additional built-in buffer of `50m` CPU and `100M` memory), and automatically sets `stardog.resources.{requests,limits}`, `stardog.javaArgs`, and JVM heap/direct memory using the guidance from the Stardog capacity planning table. This is meant to bootstrap sizing; review the generated values and pin explicit CPU/memory settings for production.
- `allocatable_label_selector` - map of node labels to identify which nodes to examine for allocatable resources (e.g. `{ target = "stardog" }`). Leave empty to consider all nodes.
- `auto_active_processor_offset` - how many vCPUs to hold back when computing `-XX:ActiveProcessorCount` (defaults to 1, so the JVM uses `allocatable_cores - 1`).
- `auto_reserved_cpu` - optional Kubernetes CPU quantity (e.g., `500m`, `0.5`) to subtract from the detected free CPU after accounting for existing pod requests (useful for an additional cushion).
- `auto_reserved_memory` - optional memory quantity (e.g., `512Mi`, `1Gi`) to subtract from the detected free memory after accounting for existing pod requests.

License handling
- `stardog_license_base64` - (required) the Stardog license encoded as base64. The module writes a Kubernetes Secret manifest with this value under `data:` (so no double base64 encoding is performed by Terraform).
- `stardog_license_secret_name` - name of the Secret to create (default: `stardog-license`).
- `stardog_license_key_filename` - filename used inside the Secret (default: `stardog.license`).

Image / runtime overrides
- The module still accepts image-related override variables (e.g., `acr_login_server`, `stardog_repository`, `stardog_tag`, `launchpad_repository`, `launchpad_tag`) and AAD related values (client IDs/secrets) which are typically passed through `helm_set` or `values_file` depending on your preference.

Requirements and notes
- The Terraform host performing `apply` must have `helm` and `python3` available on PATH because the module uses helper scripts for OCI login and calculating available node resources.
- For private OCI installs: set `chart_username` and `chart_password`. The module will only attempt `helm registry login` when `chart_url` starts with `oci://` and credentials are non-empty.
- Avoid placing long-lived secrets directly in `helm_set` if possible; consider using Kubernetes Secrets or ExternalSecrets for sensitive values.

Quick example (install from a JFrog OCI chart reference)
```
module "stardog" {
  source = "../../modules/kubernetes/stardog"
  namespace = "profile-a-sd"

  # OCI address for the chart (may also be an HTTPS URL/tarball)
  chart_url     = var.jfrog_chart_ref
  chart_version = null

  # Optional: credentials for private OCI registries
  chart_username = var.jfrog_registry_username
  chart_password = var.jfrog_registry_password

  # Pass runtime overrides using helm_set so Helm performs deep merges
  helm_set = [
    { name = "stardog.env.MSENTRA_TENANT_ID" , value = data.azurerm_client_config.current.tenant_id }
    { name = "stardog.image.repository" , value = "myacr.azurecr.io/stardog/stardog" }
    { name = "ingress.hosts[0].host" , value = "stardog.example.com" }
  ]

  # License (base64) - module writes the Secret manifest directly
  stardog_license_base64 = var.stardog_license_base64
  stardog_license_secret_name = "stardog-license"
}
```

Troubleshooting
- If you see failures related to `helm` not being found, ensure the CLI is installed on the machine running `terraform apply` (local workstation or CI runner).
- If your chart requires further customization, prefer providing a `values_file` with most settings and use `helm_set` for a small number of runtime overrides.

Further improvements
- Consider moving long-lived secrets into a secret manager (e.g., Azure Key Vault + ExternalSecrets) instead of passing them via `helm_set` to reduce exposure in logs and state.
