#!/usr/bin/env bash
set -euo pipefail

if [[ ! -f "${PWD}/terraform.tfstate" && -z "${TF_IN_AUTOMATION:-}" ]]; then
  echo "Run this script from the infra directory after terraform apply." >&2
fi

python3 - <<'PY'
import json
import subprocess
import sys

out = subprocess.check_output(["terraform", "output", "-json", "students"], text=True)
students = json.loads(out)

for key, info in students.items():
    rg = info["resource_group_name"]
    aks = info["aks_name"]
    print(f"Stopping {aks} in {rg}")
    subprocess.run(["az", "aks", "stop", "-g", rg, "-n", aks], check=False)
PY
