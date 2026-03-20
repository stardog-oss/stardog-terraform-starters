#!/usr/bin/env python3
import argparse
import json
import os
import sys
from pathlib import Path

from kubernetes import client, config
from kubernetes.client.rest import ApiException
from kubernetes.config.config_exception import ConfigException

from stardog_common.permissions import api_resource_type, canonical_resource_type
from stardog_common.stardog_admin_client import StardogAdminClient


def mask_secret(value: str | None) -> str:
    if not value:
        return "<unset>"
    return "<redacted>"


def _coerce_bool(value: object) -> bool:
    if value is None:
        return False
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.strip().lower() in {"1", "true", "yes", "on"}
    return bool(value)


def load_spec(path: Path) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError("spec must be a JSON object")

    role_value = data.get("role") or data.get("rolename")
    if not isinstance(role_value, str) or not role_value.strip():
        raise ValueError("spec.role must be a string")
    data["role"] = role_value.strip()

    action_value = data.get("action")
    if not isinstance(action_value, str) or not action_value.strip():
        raise ValueError("spec.action must be a string")
    action_trimmed = action_value.strip()
    if action_trimmed == "*" or action_trimmed.lower() == "all":
        raise ValueError("spec.action must not be '*' or 'all'")
    data["action"] = action_trimmed

    resource_type_value = data.get("resource_type") or data.get("resourceType")
    if not isinstance(resource_type_value, str) or not resource_type_value.strip():
        raise ValueError("spec.resource_type must be a string")
    data["resource_type"] = resource_type_value.strip()

    resource_value = data.get("resource")
    if not isinstance(resource_value, str) or not resource_value.strip():
        raise ValueError("spec.resource must be a string")
    data["resource"] = resource_value.strip()

    state_value = (data.get("state") or "present").lower()
    if state_value not in {"present", "absent"}:
        raise ValueError("spec.state must be 'present' or 'absent' if provided")
    data["state"] = state_value

    return data


def normalise_permission(action: str, resource_type: str, resource: str) -> tuple[str, str, str, str, str]:
    action_clean = action.strip()
    if action_clean.lower() == "all" or action_clean == "*":
        action_norm = "all"
    else:
        action_norm = action_clean.lower()

    resource_type_clean = resource_type.strip()
    if resource_type_clean in {"", "*"} or resource_type_clean.lower() == "all":
        resource_type_norm = "all"
        resource_type_display = "*"
    else:
        canonical = canonical_resource_type(resource_type_clean)
        if canonical is not None:
            resource_type_norm = canonical
            resource_type_display = api_resource_type(canonical)
        else:
            resource_type_norm = resource_type_clean.lower()
            resource_type_display = resource_type_clean

    resource_value_clean = resource.strip()
    if resource_value_clean in {"", "*"} or resource_value_clean.lower() == "all":
        resource_value_norm = "*"
    else:
        resource_value_norm = resource_value_clean

    action_token = "*" if action_norm == "all" else action_norm
    resource_type_token = "*" if resource_type_norm == "all" else resource_type_norm
    canonical = f"{action_token}:::{resource_type_token}:{resource_value_norm}"
    return action_norm, resource_type_norm, resource_type_display, resource_value_norm, canonical


def canonical_from_existing(action: str, resource: str) -> str:
    action_norm = "all" if action in {"all", "*"} else action.lower()
    if not resource or resource in {"*", "all"}:
        return f"{action_norm}:::all:*"
    if ":" in resource:
        rtype, value = resource.split(":", 1)
    else:
        rtype, value = resource, "*"
    canonical = canonical_resource_type(rtype)
    if canonical is not None:
        rtype_norm = canonical
    else:
        rtype_norm = "all" if rtype in {"", "*", "all"} else rtype.lower()
    value_norm = "*" if value in {"", "*", "all"} else value
    action_token = "*" if action_norm == "all" else action_norm
    rtype_token = "*" if rtype_norm == "all" else rtype_norm
    return f"{action_token}:::{rtype_token}:{value_norm}"


def write_status(namespace: str, name: str | None, status: dict, skip_k8s: bool) -> None:
    payload = json.dumps(status, indent=2)
    if skip_k8s or not name:
        print(payload)
        return
    try:
        try:
            config.load_incluster_config()
        except ConfigException:
            config.load_kube_config()
    except ConfigException:
        print(payload)
        return

    api = client.CoreV1Api()
    body = {"data": {"status.json": payload}}
    try:
        api.patch_namespaced_config_map(name=name, namespace=namespace, body=body)
    except ApiException as exc:
        if exc.status != 404:
            raise
        metadata = client.V1ObjectMeta(name=name, namespace=namespace)
        cm = client.V1ConfigMap(metadata=metadata, data=body["data"])
        api.create_namespaced_config_map(namespace=namespace, body=cm)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Ensure or delete a Stardog role permission assignment from a spec file.")
    parser.add_argument("--spec-file", required=True, help="Path to the assignment spec JSON file")
    parser.add_argument("--output-configmap", required=False, default=None, help="Status ConfigMap name")
    parser.add_argument("--output-namespace", default=None, help="Namespace for the status ConfigMap")
    parser.add_argument("--stardog-url", default=None, help="Override the Stardog endpoint")
    parser.add_argument("--skip-status", action="store_true", help="Print status to stdout instead of ConfigMap")
    parser.add_argument("--state", choices=["present", "absent"], default=None, help="Desired assignment state")
    parser.add_argument(
        "--idempotent-create",
        action="store_true",
        help="Report success without granting when permission is absent",
    )
    args = parser.parse_args(argv)

    spec_path = Path(args.spec_file)
    status: dict = {
        "role": None,
        "action": None,
        "resourceType": None,
        "resource": None,
        "state": None,
        "result": None,
        "idempotent": None,
        "command": None,
        "stardogUrl": None,
        "errors": [],
    }

    skip_status = args.skip_status or os.environ.get("SKIP_K8S_STATUS", "").lower() in {"1", "true", "yes"}
    if not skip_status and not args.output_configmap:
        parser.error("--output-configmap is required unless --skip-status is set")

    try:
        spec = load_spec(spec_path)
    except Exception as exc:  # noqa: BLE001
        status["errors"].append(f"Failed to load spec: {exc}")
        namespace = args.output_namespace or os.environ.get("POD_NAMESPACE", "default")
        write_status(namespace, args.output_configmap, status, skip_status)
        return 1

    role = spec["role"]
    desired_state = (args.state or spec.get("state") or "present").lower()
    action_norm, resource_type_norm, resource_type_display, resource_value_norm, canonical = normalise_permission(
        spec["action"],
        spec["resource_type"],
        spec["resource"],
    )

    status.update(
        {
            "role": role,
            "action": action_norm,
            "resourceType": resource_type_display,
            "resource": resource_value_norm,
            "state": desired_state,
            "canonical": canonical,
        }
    )

    stardog_url = args.stardog_url or spec.get("stardog_url") or "http://stardog:5820"
    status["stardogUrl"] = stardog_url
    idempotent_create = bool(
        args.idempotent_create
        or any(
            _coerce_bool(spec.get(key))
            for key in ("idempotent", "idempotent_create", "idempotentGrant")
        )
    )
    status["idempotent"] = idempotent_create
    stardog_username = os.environ.get("STARDOG_USERNAME", "admin")
    stardog_password = os.environ.get("STARDOG_PASSWORD", "admin")
    client_admin = StardogAdminClient(
        endpoint=stardog_url,
        username=stardog_username,
        password=stardog_password,
        verify_ssl=False,
    )
    masked_user = mask_secret(stardog_username)
    masked_pass = mask_secret(stardog_password)
    command_verb = "grant" if desired_state == "present" else "revoke"
    if resource_type_display == "*" and resource_value_norm == "*":
        resource_arg = "*:*"
    elif resource_type_display == "*":
        resource_arg = f"*:{resource_value_norm}"
    elif resource_value_norm == "*":
        resource_arg = f"{resource_type_display}:*"
    else:
        resource_arg = f"{resource_type_display}:{resource_value_norm}"
    status["command"] = (
        f"stardog-admin role {command_verb} --server {stardog_url} "
        f"--username {masked_user} --password {masked_pass} "
        f"-a {action_norm} -o '{resource_arg}' {role}"
    )

    namespace = args.output_namespace or os.environ.get("POD_NAMESPACE", "default")

    role_missing = False
    try:
        existing = client_admin.get_role_permissions(role)
    except Exception as exc:  # noqa: BLE001
        message = str(exc).lower()
        if desired_state == "absent" and any(token in message for token in ("does not exist", "sernf2", "404")):
            role_missing = True
            existing = set()
            status["result"] = "role missing (already deleted)"
        else:
            status["errors"].append(f"Failed to read role permissions: {exc}")
            existing = set()

    if role_missing and desired_state == "absent":
        write_status(namespace, args.output_configmap, status, skip_status)
        return 0 if not status["errors"] else 1

    existing_canonicals = {canonical_from_existing(act, res) for act, res in existing}

    if desired_state == "present":
        if canonical in existing_canonicals:
            status["result"] = "permission already present"
        else:
            if idempotent_create:
                status["result"] = "permission absent (idempotent, no change)"
            else:
                try:
                    client_admin.grant_role_permission(role, action_norm, resource_type_norm, resource_value_norm)
                    status["result"] = "permission granted"
                except Exception as exc:  # noqa: BLE001
                    message = str(exc).lower()
                    if "exists" in message or "already" in message:
                        status["result"] = "permission already present (api)"
                    else:
                        status["errors"].append(f"Failed to grant permission: {exc}")
    else:
        if canonical in existing_canonicals:
            try:
                client_admin.revoke_role_permission(role, action_norm, resource_type_norm, resource_value_norm)
                status["result"] = "permission revoked"
            except Exception as exc:  # noqa: BLE001
                message = str(exc).lower()
                if "does not exist" in message or "not found" in message:
                    status["result"] = "permission already absent (api)"
                else:
                    status["errors"].append(f"Failed to revoke permission: {exc}")
        else:
            status["result"] = "permission already absent"

    write_status(namespace, args.output_configmap, status, skip_status)

    return 0 if not status["errors"] else 1


if __name__ == "__main__":
    sys.exit(main())
