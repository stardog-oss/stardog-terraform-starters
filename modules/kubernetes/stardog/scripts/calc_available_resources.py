#!/usr/bin/env python3

import json
import math
import os
import subprocess
import sys
from typing import Dict, Iterable, Optional, Tuple


SYSTEM_NAMESPACES = {"kube-system"}
ALLOW_KUBECTL_FAILURE = os.getenv("STARDOG_AUTOCONFIG_ALLOW_K8S_FAILURE", "true").lower() in (
    "1",
    "true",
    "yes",
)


def read_stdin() -> Dict:
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError as exc:
        sys.stderr.write(f"Failed to parse external data query: {exc}\n")
        sys.exit(1)
    return data


def emit_empty_result() -> None:
    print(
        json.dumps(
            {
                "min_available_cpu_m": "0",
                "min_available_memory_bytes": "0",
                "min_allocatable_cpu_m": "0",
                "min_allocatable_memory_bytes": "0",
                "node_count": "0",
            }
        )
    )


def run_kubectl(args: Iterable[str], allow_failure: bool = False) -> Optional[Dict]:
    try:
        output = subprocess.check_output(["kubectl", *args], text=True)
    except subprocess.CalledProcessError as exc:
        sys.stderr.write(f"kubectl {' '.join(args)} failed: {exc}\n")
        if allow_failure:
            return None
        sys.exit(exc.returncode)
    try:
        return json.loads(output)
    except json.JSONDecodeError as exc:
        sys.stderr.write(f"kubectl {' '.join(args)} returned invalid JSON: {exc}\n")
        if allow_failure:
            return None
        sys.exit(1)


def cpu_to_millicores(value: str) -> int:
    if not value:
        return 0
    value = value.strip().lower()
    if value.endswith("m"):
        return int(float(value[:-1]))
    if value.endswith("n"):
        return math.floor(float(value[:-1]) / 1_000_000)
    if value.endswith("u"):
        return math.floor(float(value[:-1]) / 1_000)
    if value.endswith("k"):
        return math.floor(float(value[:-1]) * 1_000_000)
    return int(float(value) * 1000)


MEMORY_SUFFIXES = {
    "": 1,
    "ki": 1024,
    "mi": 1024**2,
    "gi": 1024**3,
    "ti": 1024**4,
    "pi": 1024**5,
    "ei": 1024**6,
    "k": 1000,
    "m": 1_000_000,
    "g": 1_000_000_000,
    "t": 1_000_000_000_000,
    "p": 1_000_000_000_000_000,
    "e": 1_000_000_000_000_000_000,
}


def memory_to_bytes(value: str) -> int:
    if not value:
        return 0
    value = value.strip()
    idx = len(value)
    while idx > 0 and not value[:idx].replace(".", "", 1).isdigit():
        idx -= 1
    number_part = value[:idx]
    suffix = value[idx:].lower()
    factor = MEMORY_SUFFIXES.get(suffix, 1)
    try:
        number = float(number_part) if "." in number_part else int(number_part)
    except ValueError:
        return 0
    return math.floor(number * factor)


def sum_pod_requests(pod: Dict) -> Tuple[int, int]:
    cpu = 0
    memory = 0

    for container in pod.get("spec", {}).get("containers", []):
        requests = container.get("resources", {}).get("requests", {})
        cpu += cpu_to_millicores(requests.get("cpu", "0"))
        memory += memory_to_bytes(requests.get("memory", "0"))

    init_cpu_requests = [
        cpu_to_millicores(c.get("resources", {}).get("requests", {}).get("cpu", "0"))
        for c in pod.get("spec", {}).get("initContainers", [])
    ]
    init_mem_requests = [
        memory_to_bytes(c.get("resources", {}).get("requests", {}).get("memory", "0"))
        for c in pod.get("spec", {}).get("initContainers", [])
    ]

    if init_cpu_requests:
        cpu = max(cpu, max(init_cpu_requests))
    if init_mem_requests:
        memory = max(memory, max(init_mem_requests))

    return cpu, memory


def main() -> None:
    query = read_stdin()
    selector_json = query.get("label_selector", "{}")
    try:
        selector = json.loads(selector_json)
    except json.JSONDecodeError:
        selector = {}

    selector_args = []
    if selector:
        selector_args = ["-l", ",".join(f"{k}={v}" for k, v in selector.items())]

    nodes = run_kubectl(["get", "nodes", *selector_args, "-o", "json"], allow_failure=ALLOW_KUBECTL_FAILURE)
    if nodes is None:
        sys.stderr.write(
            "kubectl get nodes failed; continuing with zero resources because STARDOG_AUTOCONFIG_ALLOW_K8S_FAILURE is true\n"
        )
        emit_empty_result()
        return
    node_items = nodes.get("items", [])

    if not node_items:
        emit_empty_result()
        return

    min_available_cpu = None
    min_available_memory = None
    min_allocatable_cpu = None
    min_allocatable_memory = None

    for node in node_items:
        name = node.get("metadata", {}).get("name")
        if not name:
            continue

        allocatable = node.get("status", {}).get("allocatable", {})
        alloc_cpu = cpu_to_millicores(allocatable.get("cpu", "0"))
        alloc_mem = memory_to_bytes(allocatable.get("memory", "0"))

        if min_allocatable_cpu is None or alloc_cpu < min_allocatable_cpu:
            min_allocatable_cpu = alloc_cpu
        if min_allocatable_memory is None or alloc_mem < min_allocatable_memory:
            min_allocatable_memory = alloc_mem

        pods = run_kubectl(
            [
                "get",
                "pods",
                "-A",
                "--field-selector",
                f"spec.nodeName={name}",
                "-o",
                "json",
            ],
            allow_failure=ALLOW_KUBECTL_FAILURE,
        )
        if pods is None:
            sys.stderr.write(
                f"kubectl get pods for node {name} failed; treating allocatable capacity as fully available\n"
            )
            pods_items = []
        else:
            pods_items = pods.get("items", [])

        used_cpu = 0
        used_memory = 0

        for pod in pods_items:
            namespace = pod.get("metadata", {}).get("namespace")
            if namespace not in SYSTEM_NAMESPACES:
                continue
            pod_cpu, pod_memory = sum_pod_requests(pod)
            used_cpu += pod_cpu
            used_memory += pod_memory

        available_cpu = max(alloc_cpu - used_cpu, 0)
        available_memory = max(alloc_mem - used_memory, 0)

        if min_available_cpu is None or available_cpu < min_available_cpu:
            min_available_cpu = available_cpu
        if min_available_memory is None or available_memory < min_available_memory:
            min_available_memory = available_memory

    result = {
        "min_available_cpu_m": str(min_available_cpu if min_available_cpu is not None else 0),
        "min_available_memory_bytes": str(
            min_available_memory if min_available_memory is not None else 0
        ),
        "min_allocatable_cpu_m": str(min_allocatable_cpu if min_allocatable_cpu is not None else 0),
        "min_allocatable_memory_bytes": str(
            min_allocatable_memory if min_allocatable_memory is not None else 0
        ),
        "node_count": str(len(node_items)),
    }

    print(json.dumps(result))


if __name__ == "__main__":
    main()
