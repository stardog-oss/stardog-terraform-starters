locals {
  normalized_state   = lower(trimspace(var.state))
  role_trim          = trimspace(var.role)
  action_trim        = trimspace(var.action)
  action_normalized  = lower(local.action_trim)
  resource_type_trim = trimspace(var.resource_type)
  resource_type_cli = (
    contains(["all", "*"], lower(local.resource_type_trim)) ?
    "*" :
    replace(local.resource_type_trim, "_", "-")
  )
  resource_trim      = trimspace(var.resource)
  object             = "${local.resource_type_cli}:${local.resource_trim}"
  idempotent_enabled = coalesce(var.idempotent_create, false)
  action_permission_chars = {
    create  = "C"
    delete  = "D"
    read    = "R"
    write   = "W"
    grant   = "G"
    revoke  = "K"
    execute = "X"
  }
  action_permission_char = lookup(local.action_permission_chars, local.action_normalized, "")

  role_escaped              = replace(local.role_trim, "'", "'\"'\"'")
  action_escaped            = replace(local.action_normalized, "'", "'\"'\"'")
  permission_char_escaped   = replace(local.action_permission_char, "'", "'\"'\"'")
  resource_type_cli_escaped = replace(local.resource_type_cli, "'", "'\"'\"'")
  resource_escaped          = replace(local.resource_trim, "'", "'\"'\"'")
  object_escaped            = replace(local.object, "'", "'\"'\"'")
  server_raw                = trimspace(coalesce(var.stardog_url, ""))
  server_url = (
    length(regexall("^https://[^/:]+(/.*)?$", local.server_raw)) > 0 ?
    replace(local.server_raw, "/^https://([^/:]+)(.*)$/", "https://$1:443$2") :
    local.server_raw
  )
  server_escaped   = replace(local.server_url, "'", "'\"'\"'")
  username         = try(var.container_env["STARDOG_USERNAME"], "")
  password         = try(var.container_env["STARDOG_PASSWORD"], "")
  username_escaped = replace(local.username, "'", "'\"'\"'")
  password_escaped = replace(local.password, "'", "'\"'\"'")

  spec_common = {
    role          = local.role_trim
    action        = local.action_normalized
    resource_type = local.resource_type_trim
    resource      = local.resource_trim
    object        = local.object
  }
  spec_optional = merge(
    var.stardog_url != null ? { stardog_url = local.server_url } : {},
    local.idempotent_enabled ? { idempotent = true } : {},
    var.additional_spec_fields,
  )

  spec_present_json = jsonencode(merge(local.spec_common, { state = local.normalized_state }, local.spec_optional))
  spec_absent_json  = jsonencode(merge(local.spec_common, { state = "absent" }, local.spec_optional))

  spec_present_hash = sha256(local.spec_present_json)
  spec_absent_hash  = sha256(local.spec_absent_json)

  ensure_script = <<-SCRIPT
    set -euo pipefail

    ROLE='${local.role_escaped}'
    ACTION='${local.action_escaped}'
    PERMISSION_CHAR='${local.permission_char_escaped}'
    RESOURCE_TYPE='${local.resource_type_cli_escaped}'
    RESOURCE_NAME='${local.resource_escaped}'
    OBJECT='${local.object_escaped}'
    STARDOG_SERVER='${local.server_escaped}'
    STARDOG_USERNAME='${local.username_escaped}'
    STARDOG_PASSWORD='${local.password_escaped}'

    role_exists() {
      stardog-admin --server "$STARDOG_SERVER" role list -u "$STARDOG_USERNAME" -p "$STARDOG_PASSWORD" | awk -F'|' -v role="$ROLE" '{ gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); if ($2 == role) found = 1 } END { exit(found ? 0 : 1) }'
    }

    ensure_role_exists() {
      if role_exists; then
        return 0
      fi

      stardog-admin --server "$STARDOG_SERVER" role add -u "$STARDOG_USERNAME" -p "$STARDOG_PASSWORD" -- "$ROLE" || {
        status=$?
        if role_exists; then
          return 0
        fi
        return "$status"
      }

      for attempt in $(seq 1 12); do
        if role_exists; then
          return 0
        fi
        sleep 1
      done

      echo "Stardog role '$ROLE' was not visible after creation" >&2
      return 1
    }

    permission_exists() {
      if [ -z "$PERMISSION_CHAR" ]; then
        return 1
      fi
      stardog-admin --server "$STARDOG_SERVER" role permission -u "$STARDOG_USERNAME" -p "$STARDOG_PASSWORD" -- "$ROLE" | awk -F'|' -v type="$RESOURCE_TYPE" -v name="$RESOURCE_NAME" -v perm="$PERMISSION_CHAR" '
        {
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2)
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", $3)
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", $4)
          if ($2 == type && $3 == name && index($4, perm) > 0) found = 1
        }
        END { exit(found ? 0 : 1) }
      '
    }

    case '${local.normalized_state}' in
      present)
        ensure_role_exists
        if permission_exists; then
          echo "Stardog role '$ROLE' already has '$ACTION' on '$OBJECT'"
        else
          grant_output=$(stardog-admin --server "$STARDOG_SERVER" role grant -a "$ACTION" -o "$OBJECT" -u "$STARDOG_USERNAME" -p "$STARDOG_PASSWORD" -- "$ROLE" 2>&1) || {
            status=$?
            if permission_exists || printf '%s\n' "$grant_output" | grep -qi 'exists'; then
              echo "Stardog role '$ROLE' already has '$ACTION' on '$OBJECT'"
            else
              printf '%s\n' "$grant_output" >&2
              exit "$status"
            fi
          }
        fi
        ;;
      absent)
        if ! role_exists; then
          echo "Stardog role '$ROLE' is absent; skipping permission revoke"
        elif permission_exists; then
          stardog-admin --server "$STARDOG_SERVER" role revoke -a "$ACTION" -o "$OBJECT" -u "$STARDOG_USERNAME" -p "$STARDOG_PASSWORD" -- "$ROLE"
        else
          echo "Stardog role '$ROLE' does not have '$ACTION' on '$OBJECT'"
        fi
        ;;
      *)
        echo "Unsupported role assignment state: ${local.normalized_state}" >&2
        exit 1
        ;;
    esac
  SCRIPT

  destroy_script = <<-SCRIPT
    set -euo pipefail

    ROLE='${local.role_escaped}'
    ACTION='${local.action_escaped}'
    PERMISSION_CHAR='${local.permission_char_escaped}'
    RESOURCE_TYPE='${local.resource_type_cli_escaped}'
    RESOURCE_NAME='${local.resource_escaped}'
    OBJECT='${local.object_escaped}'
    STARDOG_SERVER='${local.server_escaped}'
    STARDOG_USERNAME='${local.username_escaped}'
    STARDOG_PASSWORD='${local.password_escaped}'

    role_exists() {
      stardog-admin --server "$STARDOG_SERVER" role list -u "$STARDOG_USERNAME" -p "$STARDOG_PASSWORD" | awk -F'|' -v role="$ROLE" '{ gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); if ($2 == role) found = 1 } END { exit(found ? 0 : 1) }'
    }

    permission_exists() {
      if [ -z "$PERMISSION_CHAR" ]; then
        return 1
      fi
      stardog-admin --server "$STARDOG_SERVER" role permission -u "$STARDOG_USERNAME" -p "$STARDOG_PASSWORD" -- "$ROLE" | awk -F'|' -v type="$RESOURCE_TYPE" -v name="$RESOURCE_NAME" -v perm="$PERMISSION_CHAR" '
        {
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2)
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", $3)
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", $4)
          if ($2 == type && $3 == name && index($4, perm) > 0) found = 1
        }
        END { exit(found ? 0 : 1) }
      '
    }

    if ! role_exists; then
      echo "Stardog role '$ROLE' is absent; skipping permission revoke"
    elif permission_exists; then
      stardog-admin --server "$STARDOG_SERVER" role revoke -a "$ACTION" -o "$OBJECT" -u "$STARDOG_USERNAME" -p "$STARDOG_PASSWORD" -- "$ROLE"
    else
      echo "Stardog role '$ROLE' does not have '$ACTION' on '$OBJECT'"
    fi
  SCRIPT

  ensure_script_b64        = base64encode(local.ensure_script)
  ensure_script_b64_escape = replace(local.ensure_script_b64, "'", "'\"'\"'")

  destroy_script_b64        = base64encode(local.destroy_script)
  destroy_script_b64_escape = replace(local.destroy_script_b64, "'", "'\"'\"'")

  ensure_command = format(
    "echo '%s' | base64 -d | /usr/bin/env bash",
    local.ensure_script_b64_escape,
  )

  destroy_command = format(
    "echo '%s' | base64 -d | /usr/bin/env bash",
    local.destroy_script_b64_escape,
  )

  destroy_command_effective = var.destroy_on_deprovision ? local.destroy_command : "true"
}

resource "null_resource" "assignment" {
  triggers = {
    spec_hash       = local.spec_present_hash
    ensure_command  = local.ensure_command
    destroy_command = local.destroy_command_effective
    local_exec_env  = jsonencode(var.local_exec_env)
  }

  provisioner "local-exec" {
    when        = create
    command     = self.triggers.ensure_command
    interpreter = var.shell_interpreter
    environment = jsondecode(self.triggers.local_exec_env)
  }

  provisioner "local-exec" {
    when        = destroy
    command     = self.triggers.destroy_command
    environment = jsondecode(self.triggers.local_exec_env)
  }
}
