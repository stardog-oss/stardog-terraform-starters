locals {
  normalized_state = lower(trimspace(var.state))

  role_name         = trimspace(var.name)
  role_name_escaped = replace(local.role_name, "'", "'\"'\"'")
  server_raw        = trimspace(var.stardog_url)
  server_url = (
    length(regexall("^https://[^/:]+(/.*)?$", local.server_raw)) > 0 ?
    replace(local.server_raw, "/^https://([^/:]+)(.*)$/", "https://$1:443$2") :
    local.server_raw
  )
  server_escaped = replace(local.server_url, "'", "'\"'\"'")

  username = try(var.container_env["STARDOG_USERNAME"], "")
  password = try(var.container_env["STARDOG_PASSWORD"], "")

  username_escaped = replace(local.username, "'", "'\"'\"'")
  password_escaped = replace(local.password, "'", "'\"'\"'")

  spec_present_json = jsonencode({
    role        = local.role_name
    state       = local.normalized_state
    stardog_url = local.server_url
  })

  spec_absent_json = jsonencode({
    role        = local.role_name
    state       = "absent"
    stardog_url = local.server_url
  })

  spec_present_hash = sha256(local.spec_present_json)
  spec_absent_hash  = sha256(local.spec_absent_json)

  ensure_script = <<-SCRIPT
    set -euo pipefail

    ROLE='${local.role_name_escaped}'
    STARDOG_SERVER='${local.server_escaped}'
    STARDOG_USERNAME='${local.username_escaped}'
    STARDOG_PASSWORD='${local.password_escaped}'

    role_exists() {
      stardog-admin --server "$STARDOG_SERVER" role list -u "$STARDOG_USERNAME" -p "$STARDOG_PASSWORD" | awk -F'|' -v role="$ROLE" '{ gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); if ($2 == role) found = 1 } END { exit(found ? 0 : 1) }'
    }

    wait_for_role() {
      for attempt in $(seq 1 12); do
        if role_exists; then
          return 0
        fi
        sleep 1
      done
      echo "Stardog role '$ROLE' was not visible after creation" >&2
      return 1
    }

    case '${local.normalized_state}' in
      present)
        if role_exists; then
          echo "Stardog role '$ROLE' already exists"
        else
          stardog-admin --server "$STARDOG_SERVER" role add -u "$STARDOG_USERNAME" -p "$STARDOG_PASSWORD" -- "$ROLE"
          wait_for_role
        fi
        ;;
      absent)
        if role_exists; then
          stardog-admin --server "$STARDOG_SERVER" role remove --force -u "$STARDOG_USERNAME" -p "$STARDOG_PASSWORD" -- "$ROLE"
        else
          echo "Stardog role '$ROLE' is already absent"
        fi
        ;;
      *)
        echo "Unsupported role state: ${local.normalized_state}" >&2
        exit 1
        ;;
    esac
  SCRIPT

  destroy_script = <<-SCRIPT
    set -euo pipefail

    ROLE='${local.role_name_escaped}'
    STARDOG_SERVER='${local.server_escaped}'
    STARDOG_USERNAME='${local.username_escaped}'
    STARDOG_PASSWORD='${local.password_escaped}'

    role_exists() {
      stardog-admin --server "$STARDOG_SERVER" role list -u "$STARDOG_USERNAME" -p "$STARDOG_PASSWORD" | awk -F'|' -v role="$ROLE" '{ gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); if ($2 == role) found = 1 } END { exit(found ? 0 : 1) }'
    }

    if role_exists; then
      stardog-admin --server "$STARDOG_SERVER" role remove --force -u "$STARDOG_USERNAME" -p "$STARDOG_PASSWORD" -- "$ROLE"
    else
      echo "Stardog role '$ROLE' is already absent"
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

resource "null_resource" "role" {
  triggers = {
    spec_hash       = local.spec_present_hash
    ensure_command  = local.ensure_command
    destroy_command = local.destroy_command_effective
    local_exec_env  = jsonencode(var.local_exec_env)
    # Routed through triggers (same jsonencode/jsondecode pattern local_exec_env already uses) so
    # the destroy-time provisioner below can reach it - destroy-time provisioners may only
    # reference self/count.index/each.key, never var.* directly (a real Terraform constraint, not
    # an oversight in the original code - confirmed via `terraform validate` rejecting a direct
    # var.shell_interpreter reference there with "Invalid reference from destroy provisioner").
    shell_interpreter = jsonencode(var.shell_interpreter)
  }

  provisioner "local-exec" {
    when        = create
    command     = self.triggers.ensure_command
    interpreter = var.shell_interpreter
    environment = jsondecode(self.triggers.local_exec_env)
  }

  provisioner "local-exec" {
    when = destroy
    # interpreter added - real bug this fixes: the create-time provisioner right above sets this
    # explicitly, but this one didn't, silently falling back to Terraform's own default interpreter
    # instead of respecting a shell_interpreter override on destroy.
    command     = self.triggers.destroy_command
    interpreter = jsondecode(self.triggers.shell_interpreter)
    environment = jsondecode(self.triggers.local_exec_env)
  }
}
