#!/usr/bin/env python3
import argparse
import json
import sys
from pathlib import Path

from stardog_role import reconcile as role_reconcile
from stardog_role_assignment import reconcile as assign_reconcile


def detect_operation(spec_path: Path) -> str:
    try:
        data = json.loads(spec_path.read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001
        raise ValueError(f"Failed to read spec file '{spec_path}': {exc}") from exc

    if isinstance(data, dict) and {"action", "resource_type"} & data.keys():
        return "role-assignment"
    return "role"


def build_forward_args(ns: argparse.Namespace, *, include_assignment_only: bool = False) -> list[str]:
    args: list[str] = ["--spec-file", ns.spec_file]
    if getattr(ns, "output_configmap", None):
        args.extend(["--output-configmap", ns.output_configmap])
    if getattr(ns, "output_namespace", None):
        args.extend(["--output-namespace", ns.output_namespace])
    if ns.stardog_url:
        args.extend(["--stardog-url", ns.stardog_url])
    if ns.skip_status:
        args.append("--skip-status")
    if ns.state:
        args.extend(["--state", ns.state])
    if include_assignment_only and getattr(ns, "idempotent_create", False):
        args.append("--idempotent-create")
    return args


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Stardog operations CLI")
    parser.add_argument("--spec-file", required=True, help="Path to the spec JSON file")
    parser.add_argument("--output-configmap", required=False, default=None, help="Status ConfigMap name")
    parser.add_argument("--output-namespace", default=None, help="Namespace for the status ConfigMap")
    parser.add_argument("--stardog-url", default=None, help="Override the Stardog endpoint")
    parser.add_argument("--skip-status", action="store_true", help="Print status to stdout instead of ConfigMap")
    parser.add_argument("--state", choices=["present", "absent"], default=None, help="Desired state override")
    parser.add_argument(
        "--idempotent-create",
        action="store_true",
        help="Report success without granting when permission is missing (role assignment only)",
    )
    parser.add_argument(
        "--operation",
        choices=["role", "role-assignment"],
        default=None,
        help="Operation to run (auto-detected from spec when omitted)",
    )
    ns = parser.parse_args(argv)

    spec_path = Path(ns.spec_file)
    operation = ns.operation or detect_operation(spec_path)

    if not ns.skip_status and not ns.output_configmap:
        parser.error("--output-configmap is required unless --skip-status is set")

    forward_args = build_forward_args(ns, include_assignment_only=(operation == "role-assignment"))

    if operation == "role-assignment":
        return assign_reconcile.main(forward_args)
    return role_reconcile.main(forward_args)


if __name__ == "__main__":
    sys.exit(main())
