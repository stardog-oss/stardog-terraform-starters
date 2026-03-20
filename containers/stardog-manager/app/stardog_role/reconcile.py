#!/usr/bin/env python3
import argparse
import json
import os
import sys
from pathlib import Path

from kubernetes import client, config
from kubernetes.client.rest import ApiException
from kubernetes.config.config_exception import ConfigException

from stardog_common.stardog_admin_client import StardogAdminClient


def mask_secret(value: str | None) -> str:
    if not value:
        return "<unset>"
    return "<redacted>"


def load_spec(path: Path) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError("spec must be a JSON object")
    role_value = data.get("role") or data.get("rolename")
    if not isinstance(role_value, str) or not role_value.strip():
        raise ValueError("spec.role must be a string")
    data["role"] = role_value.strip()
    state_value = (data.get("state") or "present").lower()
    if state_value not in {"present", "absent"}:
        raise ValueError("spec.state must be 'present' or 'absent' if provided")
    data["state"] = state_value
    return data


def write_status_configmap(namespace: str, name: str | None, status: dict, skip_k8s: bool = False) -> None:
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
    parser = argparse.ArgumentParser(description="Ensure or delete a Stardog role based on a spec JSON file.")
    parser.add_argument("--spec-file", required=True, help="Path to the role spec JSON file")
    parser.add_argument("--output-configmap", required=False, default=None, help="Status ConfigMap name")
    parser.add_argument("--output-namespace", default=None, help="Namespace for the status ConfigMap")
    parser.add_argument("--stardog-url", default=None, help="Override the Stardog endpoint")
    parser.add_argument("--skip-status", action="store_true", help="Print status to stdout instead of ConfigMap")
    parser.add_argument("--state", choices=["present", "absent"], default=None, help="Desired role state")
    args = parser.parse_args(argv)

    spec_path = Path(args.spec_file)
    status: dict = {
        "role": None,
        "state": None,
        "result": None,
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
        write_status_configmap(namespace, args.output_configmap, status, skip_k8s=skip_status)
        return 1

    role_name: str = spec["role"]
    desired_state = (args.state or spec.get("state") or "present").lower()
    status["role"] = role_name
    status["state"] = desired_state

    stardog_url = args.stardog_url or spec.get("stardog_url") or "http://stardog:5820"
    status["stardogUrl"] = stardog_url
    stardog_username = os.environ.get("STARDOG_USERNAME")
    stardog_password = os.environ.get("STARDOG_PASSWORD")
    if not stardog_username or not stardog_password:
        raise RuntimeError("STARDOG_USERNAME and STARDOG_PASSWORD environment variables must be set")
    client_admin = StardogAdminClient(
        endpoint=stardog_url,
        username=stardog_username,
        password=stardog_password,
        verify_ssl=False,
    )
    masked_user = mask_secret(stardog_username)
    masked_pass = mask_secret(stardog_password)
    command_action = "create" if desired_state == "present" else "delete"
    status["command"] = (
        f"stardog-admin role {command_action} "
        f"--server {stardog_url} --username {masked_user} --password {masked_pass} {role_name}"
    )

    namespace = args.output_namespace or os.environ.get("POD_NAMESPACE", "default")

    if desired_state == "present":
        try:
            client_admin.ensure_role(role_name)
            status["result"] = "role ensured"
        except Exception as exc:  # noqa: BLE001
            status["errors"].append(f"Failed to ensure role '{role_name}': {exc}")
    else:
        try:
            client_admin.delete_role(role_name)
            status["result"] = "role deleted"
        except Exception as exc:  # noqa: BLE001
            status["errors"].append(f"Failed to delete role '{role_name}': {exc}")

    write_status_configmap(namespace, args.output_configmap, status, skip_k8s=skip_status)

    return 0 if not status["errors"] else 1


if __name__ == "__main__":
    sys.exit(main())
