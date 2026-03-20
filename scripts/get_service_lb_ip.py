#!/usr/bin/env python3
"""Helper used via the external data source to read a Service load balancer IP."""
import json
import os
import subprocess
import sys
import tempfile

def main() -> None:
    try:
        query = json.load(sys.stdin)
    except Exception:
        query = {}

    name = (query or {}).get("name", "")
    namespace = (query or {}).get("namespace", "")
    kubeconfig = (query or {}).get("kubeconfig", "")
    kind = (query or {}).get("kind", "service").lower()
    if kind not in ("service", "gateway"):
        kind = "service"

    result = {"ip": "", "hostname": ""}

    if not name or not namespace:
        print(json.dumps(result))
        return

    aks_rg = (query or {}).get("aks_resource_group", "")
    aks_name = (query or {}).get("aks_cluster_name", "")
    kubeconfig_path = os.path.expanduser(str(kubeconfig)) if kubeconfig else ""
    effective_kubeconfig = kubeconfig_path
    if kubeconfig_path and aks_rg and aks_name:
        kubeconfig_dir = os.path.dirname(kubeconfig_path)
        if kubeconfig_dir:
            os.makedirs(kubeconfig_dir, exist_ok=True)
        def refresh_kubeconfig(path: str) -> int:
            return subprocess.run(
                [
                    "az",
                    "aks",
                    "get-credentials",
                    "-g",
                    aks_rg,
                    "-n",
                    aks_name,
                    "--file",
                    path,
                    "--overwrite-existing",
                ],
                check=False,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            ).returncode
        if refresh_kubeconfig(kubeconfig_path) != 0:
            fd, temp_path = tempfile.mkstemp(prefix="kubeconfig-", suffix=".yaml")
            os.close(fd)
            if refresh_kubeconfig(temp_path) == 0:
                effective_kubeconfig = temp_path

    def run_kubectl(config_path: str) -> subprocess.CompletedProcess[str]:
        cmd = ["kubectl"]
        if config_path:
            cmd.extend(["--kubeconfig", config_path])
        cmd.extend(["-n", namespace, "get", kind, name, "-o", "json"])
        return subprocess.run(cmd, check=False, capture_output=True, text=True)

    try:
        proc = run_kubectl(effective_kubeconfig)
    except FileNotFoundError:
        print(json.dumps(result))
        return

    if proc.returncode != 0 and kubeconfig_path and aks_rg and aks_name:
        fd, temp_path = tempfile.mkstemp(prefix="kubeconfig-", suffix=".yaml")
        os.close(fd)
        if refresh_kubeconfig(temp_path) == 0:
            effective_kubeconfig = temp_path
            proc = run_kubectl(effective_kubeconfig)

    if proc.returncode != 0:
        print(json.dumps(result))
        return

    try:
        svc = json.loads(proc.stdout)
    except json.JSONDecodeError:
        print(json.dumps(result))
        return

    status = svc.get("status") or {}
    if kind == "service":
        ingress_list = status.get("loadBalancer", {}).get("ingress", []) or []
        if ingress_list:
            first = ingress_list[0]
            result["ip"] = first.get("ip", "") or ""
            result["hostname"] = first.get("hostname", "") or ""
    else:
        addr_list = status.get("addresses", []) or []
        if addr_list:
            for addr in addr_list:
                for key in ("value", "ip", "hostname", "address"):
                    value = addr.get(key)
                    if value:
                        result["ip"] = value
                        break
                if result["ip"]:
                    break
        if not result["ip"]:
            selectors = [
                f"gateway.networking.k8s.io/gateway-name={name}",
                f"gateway.envoyproxy.io/owning-gateway={name}",
            ]
            for selector in selectors:
                for svc_cmd in (
                    base_cmd + ["-n", namespace, "get", "svc", "-l", selector, "-o", "json"],
                    base_cmd + ["get", "svc", "-A", "-l", selector, "-o", "json"],
                ):
                    proc = subprocess.run(svc_cmd, check=False, capture_output=True, text=True)
                    if proc.returncode != 0:
                        continue
                    try:
                        svc_list = json.loads(proc.stdout)
                    except json.JSONDecodeError:
                        continue
                    for item in svc_list.get("items", []) or []:
                        ingress_list = item.get("status", {}).get("loadBalancer", {}).get("ingress", []) or []
                        if ingress_list:
                            first = ingress_list[0]
                            result["ip"] = first.get("ip", "") or ""
                            result["hostname"] = first.get("hostname", "") or ""
                            break
                    if result["ip"]:
                        break
                if result["ip"]:
                    break

    print(json.dumps(result))


if __name__ == "__main__":
    main()
