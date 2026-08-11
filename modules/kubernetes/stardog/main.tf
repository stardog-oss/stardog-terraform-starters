data "kubernetes_nodes" "allocatable" {
  count = var.auto_configure_resources ? 1 : 0
}

data "external" "stardog_node_availability" {
  count   = var.auto_configure_resources ? 1 : 0
  program = ["python3", "${path.module}/scripts/calc_available_resources.py"]
  query = {
    label_selector = jsonencode(var.allocatable_label_selector)
  }
}

locals {
  auto_reserved_cpu_input = lower(trimspace(coalesce(var.auto_reserved_cpu, "0")))
  auto_reserved_cpu_m = (
    length(local.auto_reserved_cpu_input) == 0 ? 0 :
    endswith(local.auto_reserved_cpu_input, "m") ?
    tonumber(replace(local.auto_reserved_cpu_input, "m", "")) :
    endswith(local.auto_reserved_cpu_input, "n") ?
    floor(tonumber(replace(local.auto_reserved_cpu_input, "n", "")) / 1000000) :
    endswith(local.auto_reserved_cpu_input, "u") ?
    floor(tonumber(replace(local.auto_reserved_cpu_input, "u", "")) / 1000) :
    endswith(local.auto_reserved_cpu_input, "k") ?
    floor(tonumber(replace(local.auto_reserved_cpu_input, "k", "")) * 1000000) :
    floor(tonumber(local.auto_reserved_cpu_input) * 1000)
  )

  auto_reserved_memory_input = trimspace(coalesce(var.auto_reserved_memory, "0"))
  auto_reserved_memory_bytes = (
    length(local.auto_reserved_memory_input) == 0 ? 0 : floor(
      try(tonumber(try(regexall("([0-9.]+)", local.auto_reserved_memory_input)[0][0], "0")), 0) *
      lookup({
        ""   = 1,
        "ki" = 1024,
        "mi" = 1048576,
        "gi" = 1073741824,
        "ti" = 1099511627776,
        "pi" = 1125899906842624,
        "ei" = 1152921504606846976,
        "k"  = 1000,
        "m"  = 1000000,
        "g"  = 1000000000,
        "t"  = 1000000000000,
        "p"  = 1000000000000000,
        "e"  = 1000000000000000000,
      }, lower(try(regexall("([A-Za-z]+)$", local.auto_reserved_memory_input)[0][0], "")), 1)
    )
  )

  gib_in_bytes                = 1073741824
  auto_buffer_cpu_m           = 50
  auto_buffer_memory_bytes    = 100000000
  total_reserved_cpu_m        = local.auto_reserved_cpu_m + local.auto_buffer_cpu_m
  total_reserved_memory_bytes = local.auto_reserved_memory_bytes + local.auto_buffer_memory_bytes

  stardog_node_availability_result        = var.auto_configure_resources ? try(data.external.stardog_node_availability[0].result, {}) : {}
  stardog_raw_available_cpu_m             = try(tonumber(lookup(local.stardog_node_availability_result, "min_available_cpu_m", "")), null)
  stardog_raw_available_memory_bytes      = try(tonumber(lookup(local.stardog_node_availability_result, "min_available_memory_bytes", "")), null)
  stardog_script_allocatable_cpu_m        = try(tonumber(lookup(local.stardog_node_availability_result, "min_allocatable_cpu_m", "")), null)
  stardog_script_allocatable_memory_bytes = try(tonumber(lookup(local.stardog_node_availability_result, "min_allocatable_memory_bytes", "")), null)

  stardog_node_candidates = (
    var.auto_configure_resources && length(data.kubernetes_nodes.allocatable) > 0
    ? data.kubernetes_nodes.allocatable[0].nodes
    : []
  )

  stardog_nodes_filtered = length(var.allocatable_label_selector) == 0 ? local.stardog_node_candidates : [
    for node in local.stardog_node_candidates : node
    if alltrue([
      for selector_key, selector_value in var.allocatable_label_selector :
      try(node.metadata[0].labels[selector_key], "") == selector_value
    ])
  ]

  stardog_nodes_for_capacity = length(local.stardog_nodes_filtered) > 0 ? local.stardog_nodes_filtered : local.stardog_node_candidates

  stardog_cpu_strings = [
    for node in local.stardog_nodes_for_capacity :
    try(node.status[0].allocatable["cpu"], null)
    if try(node.status[0].allocatable["cpu"], null) != null
  ]

  stardog_cpu_millicores = [
    for cpu in local.stardog_cpu_strings :
    (
      endswith(cpu, "m") ?
      tonumber(replace(cpu, "m", "")) :
      endswith(cpu, "n") ?
      floor(tonumber(replace(cpu, "n", "")) / 1000000) :
      endswith(cpu, "u") ?
      floor(tonumber(replace(cpu, "u", "")) / 1000) :
      endswith(cpu, "k") ?
      floor(tonumber(replace(cpu, "k", "")) * 1000000) :
      floor(tonumber(cpu) * 1000)
    )
  ]

  stardog_memory_strings = [
    for node in local.stardog_nodes_for_capacity :
    try(node.status[0].allocatable["memory"], null)
    if try(node.status[0].allocatable["memory"], null) != null
  ]

  stardog_memory_bytes = [
    for mem in local.stardog_memory_strings : floor(
      try(tonumber(try(regexall("([0-9.]+)", mem)[0][0], "0")), 0) *
      lookup({
        ""   = 1,
        "ki" = 1024,
        "mi" = 1048576,
        "gi" = 1073741824,
        "ti" = 1099511627776,
        "pi" = 1125899906842624,
        "ei" = 1152921504606846976,
        "k"  = 1000,
        "m"  = 1000000,
        "g"  = 1000000000,
        "t"  = 1000000000000,
        "p"  = 1000000000000000,
        "e"  = 1000000000000000000,
      }, lower(try(regexall("([A-Za-z]+)$", mem)[0][0], "")), 1)
    )
  ]

  stardog_allocatable_cpu_m = (
    length(local.stardog_cpu_millicores) > 0
    ? min(local.stardog_cpu_millicores...)
    : local.stardog_script_allocatable_cpu_m
  )
  stardog_available_cpu_m_raw = (
    local.stardog_raw_available_cpu_m != null
    ? local.stardog_raw_available_cpu_m
    : local.stardog_allocatable_cpu_m
  )
  stardog_available_cpu_m = (
    local.stardog_available_cpu_m_raw != null
    ? max(0, local.stardog_available_cpu_m_raw - local.total_reserved_cpu_m)
    : null
  )
  stardog_available_cpu_string = (
    local.stardog_available_cpu_m == null ? null :
    local.stardog_available_cpu_m <= 0 ? null :
    format("%dm", local.stardog_available_cpu_m)
  )

  stardog_available_cpu_cores = (
    local.stardog_available_cpu_m == null ? null :
    local.stardog_available_cpu_m <= 0 ? null :
    local.stardog_available_cpu_m / 1000
  )

  stardog_allocatable_memory_bytes = (
    length(local.stardog_memory_bytes) > 0
    ? min(local.stardog_memory_bytes...)
    : local.stardog_script_allocatable_memory_bytes
  )
  stardog_available_memory_bytes_raw = (
    local.stardog_raw_available_memory_bytes != null
    ? local.stardog_raw_available_memory_bytes
    : local.stardog_allocatable_memory_bytes
  )
  stardog_available_memory_bytes = (
    local.stardog_available_memory_bytes_raw != null
    ? max(0, local.stardog_available_memory_bytes_raw - local.total_reserved_memory_bytes)
    : null
  )
  stardog_available_memory_value = (
    local.stardog_available_memory_bytes == null || local.stardog_available_memory_bytes == 0 ? null :
    (
      local.stardog_available_memory_bytes >= local.gib_in_bytes && local.stardog_available_memory_bytes % local.gib_in_bytes == 0 ?
      format("%dGi", local.stardog_available_memory_bytes / local.gib_in_bytes) :
      format("%dMi", max(floor(local.stardog_available_memory_bytes / 1048576), 1))
    )
  )

  stardog_memory_profiles = [
    {
      max_bytes  = 4 * local.gib_in_bytes
      heap_gib   = 1
      direct_gib = 2
    },
    {
      max_bytes  = 8 * local.gib_in_bytes
      heap_gib   = 2
      direct_gib = 4
    },
    {
      max_bytes  = 16 * local.gib_in_bytes
      heap_gib   = 4
      direct_gib = 8
    },
    {
      max_bytes  = 32 * local.gib_in_bytes
      heap_gib   = 8
      direct_gib = 16
    },
    {
      max_bytes  = 64 * local.gib_in_bytes
      heap_gib   = 16
      direct_gib = 32
    },
    {
      max_bytes  = null
      heap_gib   = 32
      direct_gib = 64
    }
  ]

  stardog_memory_profile_candidates = (
    local.stardog_available_memory_bytes == null ? [] :
    local.stardog_available_memory_bytes <= 0 ? [] : [
      for profile in local.stardog_memory_profiles : profile
      if profile.max_bytes == null || local.stardog_available_memory_bytes <= profile.max_bytes
    ]
  )

  stardog_selected_memory_profile = length(local.stardog_memory_profile_candidates) > 0 ? local.stardog_memory_profile_candidates[0] : null
  stardog_jvm_heap_string         = local.stardog_selected_memory_profile != null ? format("%dg", local.stardog_selected_memory_profile.heap_gib) : null
  stardog_jvm_direct_string       = local.stardog_selected_memory_profile != null ? format("%dg", local.stardog_selected_memory_profile.direct_gib) : null

  stardog_available_cpu_rounded = (
    local.stardog_available_cpu_cores != null
    ? floor(local.stardog_available_cpu_cores) + (
      local.stardog_available_cpu_cores - floor(local.stardog_available_cpu_cores) > 0.5 ? 1 : 0
    )
    : null
  )

  stardog_auto_java_count = (
    local.stardog_available_cpu_rounded != null
    ? max(local.stardog_available_cpu_rounded - var.auto_active_processor_offset, 1)
    : null
  )

  stardog_auto_resource_sets = var.auto_configure_resources && local.stardog_available_cpu_string != null && local.stardog_available_memory_value != null ? [
    {
      name  = "stardog.resources.requests.cpu"
      value = local.stardog_available_cpu_string
    },
    {
      name  = "stardog.resources.limits.cpu"
      value = local.stardog_available_cpu_string
    },
    {
      name  = "stardog.resources.requests.memory"
      value = local.stardog_available_memory_value
    },
    {
      name  = "stardog.resources.limits.memory"
      value = local.stardog_available_memory_value
    }
  ] : []

  stardog_auto_java_set = var.auto_configure_resources && local.stardog_auto_java_count != null ? [
    {
      name  = "stardog.javaArgs"
      value = format("-XX:ActiveProcessorCount=%d", local.stardog_auto_java_count)
    }
  ] : []

  stardog_auto_jvm_set = var.auto_configure_resources && local.stardog_jvm_heap_string != null && local.stardog_jvm_direct_string != null ? [
    {
      name  = "stardog.jvm.minHeap"
      value = local.stardog_jvm_heap_string
    },
    {
      name  = "stardog.jvm.maxHeap"
      value = local.stardog_jvm_heap_string
    },
    {
      name  = "stardog.jvm.directMem"
      value = local.stardog_jvm_direct_string
    }
  ] : []

  cachetarget_auto_resource_sets = var.cachetarget_enabled && var.auto_configure_resources && local.stardog_available_cpu_string != null && local.stardog_available_memory_value != null ? [
    {
      name  = "cachetarget.resources.requests.cpu"
      value = local.stardog_available_cpu_string
    },
    {
      name  = "cachetarget.resources.limits.cpu"
      value = local.stardog_available_cpu_string
    },
    {
      name  = "cachetarget.resources.requests.memory"
      value = local.stardog_available_memory_value
    },
    {
      name  = "cachetarget.resources.limits.memory"
      value = local.stardog_available_memory_value
    }
  ] : []

  cachetarget_auto_jvm_set = var.cachetarget_enabled && var.auto_configure_resources && local.stardog_jvm_heap_string != null && local.stardog_jvm_direct_string != null ? [
    {
      name  = "cachetarget.jvm.minHeap"
      value = local.stardog_jvm_heap_string
    },
    {
      name  = "cachetarget.jvm.maxHeap"
      value = local.stardog_jvm_heap_string
    },
    {
      name  = "cachetarget.jvm.directMem"
      value = local.stardog_jvm_direct_string
    }
  ] : []

  stardog_effective_helm_set = concat(
    var.helm_set,
    local.stardog_auto_resource_sets,
    local.cachetarget_auto_resource_sets,
    local.stardog_auto_java_set,
    local.stardog_auto_jvm_set,
    local.cachetarget_auto_jvm_set
  )
}

resource "kubernetes_namespace_v1" "stardog" {
  metadata {
    name = var.namespace
  }
}


# 1) Log in to the OCI registry once per apply (idempotent)
resource "null_resource" "helm_registry_login_oci" {
  # This resource always exists so other resources can `depends_on` it.
  # The provisioner itself is a no-op unless the chart_url looks like an OCI URL
  # and a username was provided.
  triggers = {
    registry    = var.chart_url
    username    = var.chart_username
    password_sh = sha256(var.chart_password) # re-run login if password changes
  }

  provisioner "local-exec" {
    interpreter = var.shell_interpreter
    command     = <<-EOT
      set -euo pipefail

      # Ensure Helm is present
      helm version >/dev/null

      # Use default Helm config path (~/.config/helm/registry/config.json),
      # so the Helm provider can read the same credentials.
      export XDG_CONFIG_HOME="$${XDG_CONFIG_HOME:-$HOME/.config}"
      mkdir -p "$XDG_CONFIG_HOME/helm/registry"

      # Only run login when chart_url is OCI and username provided
      if [[ "${var.chart_url}" != oci://* || "${var.chart_username}" == "" ]]; then
        echo "Skipping OCI login: chart_url not OCI or username not provided"
        # Record skip in debug log so users can see login was intentionally skipped
        mkdir -p "${path.module}/.debug"
        echo "SKIP_LOGIN $(date -u) REASON=not_oci_or_missing_username REGISTRY=${var.chart_url}" >> "${path.module}/.debug/helm_registry_login.log"
        exit 0
      fi

  # extract registry host from OCI URL (remove oci:// and take host)
  url="${var.chart_url}"
  # remove leading oci:// if present (escape so Terraform doesn't interpolate)
  url="$${url#oci://}"
  # take the host segment before the first slash
  REGISTRY_HOST="$${url%%/*}"

      # Best-effort logout (avoids duplicate entries), then login
      helm registry logout "$${REGISTRY_HOST}" >/dev/null 2>&1 || true
      helm registry login "$${REGISTRY_HOST}" \
        --username '${var.chart_username}' \
        --password '${var.chart_password}'

      # On successful login, write a small debug entry so apply logs can be
      # inspected later without re-running terraform.
  # mkdir -p "${path.module}/.debug"
  # echo "LOGIN_OK $(date -u) REGISTRY=$${REGISTRY_HOST} USER='${var.chart_username}'" >> "${path.module}/.debug/helm_registry_login.log"
    EOT
  }
}

# (Optional) Clean up the login on destroy (not required, but tidy)
/* Removed optional destroy-time helm registry logout provisioner.
   Destroy-time provisioners have strict reference rules and the logout was
   only tidy/optional. If you need explicit logout on destroy, consider
   handling it out-of-band in CI or with a separate script. */

resource "helm_release" "stardog" {
  count = var.chart_url != null && var.chart_url != "" ? 1 : 0

  name      = var.release_name
  namespace = var.namespace
  # chart supports both OCI (oci://...) and HTTP(S) chart archive URLs
  chart = var.chart_url
  # If chart_version is not set (null or empty), pass null so the provider
  # won't write an empty string in the configuration and conflict with a
  # version inferred from the chart_url (e.g., OCI refs with :tag).
  version = var.chart_version != null && var.chart_version != "" ? var.chart_version : null

  values = [file(var.values_file)]
  set    = local.stardog_effective_helm_set
  create_namespace = false
  # Ensure namespace, license, and (if configured) OCI registry login are present
  depends_on = [kubernetes_namespace_v1.stardog, kubernetes_secret_v1.stardog_license, null_resource.helm_registry_login_oci]

  replace         = var.helm_replace
  atomic          = var.helm_atomic
  cleanup_on_fail = var.helm_cleanup_on_fail
  force_update    = var.helm_force_update
  timeout         = var.helm_timeout
  wait            = var.helm_wait
}

resource "kubernetes_secret_v1" "stardog_license" {
  metadata {
    name      = var.stardog_license_secret_name
    namespace = var.namespace
  }

  binary_data = {
    (var.stardog_license_key_filename) = trimspace(var.stardog_license_base64)
  }

  type = "Opaque"

  depends_on = [kubernetes_namespace_v1.stardog]
}

/* Update helm depends to include the license secret. */
/* Note: helm_release already has static depends_on on kubernetes_namespace + helm registry login helper. */

# Optional local pull: run helm pull to fetch the OCI chart into the module folder so
# helm_release can install from a local tgz. This works around provider/OCI issues.
/* chart pre-pull / JFrog export logic removed — installs now use the chart directly from
   the configured repo or OCI URI (see cert-manager for a simple example). */

resource "null_resource" "debug_print_helm_command" {
  count = var.debug_print_helm_command ? 1 : 0

  provisioner "local-exec" {
    interpreter = var.shell_interpreter
    environment = {
      RELEASE_NAME = var.release_name
      NAMESPACE    = var.namespace
      CHART        = var.chart_url
      CHART_VERSION = var.chart_version
      HELM_SET_JSON = jsonencode(local.stardog_effective_helm_set)

    }

    command = <<-EOT
      set -euo pipefail
      debugdir="${path.module}/.debug"
      mkdir -p "$debugdir"

  # Dump base values: prefer a provided values file, else dump var.values_yaml
  if [ "${var.values_file}" != "" ]; then
    echo "Reading base values from path: ${var.values_file}" > "$debugdir/base_values.yaml"
    cat "${var.values_file}" >> "$debugdir/base_values.yaml"
  else
    cat > "$debugdir/base_values.yaml" <<-YAML
${var.values_yaml}
YAML
  fi
  echo "Wrote base_values.yaml to $debugdir/base_values.yaml" >&2

  set_args_file="$debugdir/set_args.txt"
  python3 - <<'PY' > "$set_args_file"
import json
import os
import shlex

items = json.loads(os.environ.get("HELM_SET_JSON", "[]"))
args = []
for item in items:
    name = item.get("name", "")
    value = "" if item.get("value") is None else str(item.get("value"))
    if name:
        args.append(f"--set-string {shlex.quote(name)}={shlex.quote(value)}")
print(" ".join(args))
PY
  echo "Wrote set args to $set_args_file" >&2

      # If a Helm release exists, dump all info to info.log
      if command -v helm >/dev/null 2>&1 ; then
        echo "Running: helm get all $RELEASE_NAME -n $NAMESPACE" > "$debugdir/info.log"
        helm get all "$RELEASE_NAME" -n "$NAMESPACE" >> "$debugdir/info.log" 2>&1 || echo "helm get failed or release not present" >> "$debugdir/info.log"
        echo "Wrote helm get output to $debugdir/info.log" >&2
      else
        echo "helm not installed; cannot run helm get" > "$debugdir/info.log"
      fi

      chart_version_arg=""
      if [ -n "$CHART_VERSION" ]; then
        chart_version_arg="--version $CHART_VERSION"
      fi

      cat > "$debugdir/helm_template.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
helm template "$RELEASE_NAME" "$CHART" -n "$NAMESPACE" -f "$debugdir/base_values.yaml" $chart_version_arg \\
  $(cat "$set_args_file")
EOF

      cat > "$debugdir/helm_install.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
helm upgrade --install "$RELEASE_NAME" "$CHART" -n "$NAMESPACE" -f "$debugdir/base_values.yaml" $chart_version_arg \\
  $(cat "$set_args_file")
EOF

      chmod +x "$debugdir/helm_template.sh" "$debugdir/helm_install.sh"
      echo "Wrote helm_template.sh and helm_install.sh to $debugdir" >&2
    EOT
  }
  depends_on = [kubernetes_secret_v1.stardog_license]
}
