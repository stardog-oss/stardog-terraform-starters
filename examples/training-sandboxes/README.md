# Training Sandboxes

Provision one AKS/ACR/AKV/Public IP sandbox per student using the existing modules in this repo.

## What it creates
- Resource group per student
- AKS cluster + user node pools
- Shared ACR used by all student AKS clusters
- AKV (unique name per student)
- Static Public IP
- RBAC: student gets access to **their** RG only
- Shared ACR access granted via the student group (falls back to per-student if the group is disabled)
- Optional: student tfstate container + group + role assignment
- Optional: daily AKS stop schedule (safety net)
- Optional: per-student DNS records in a delegated sub-zone

## Prereqs
- Azure CLI authenticated to the target subscription
- Terraform >= 1.5
- `kubectl` installed (required by the AKS module local-exec unless disabled)
- Permission to invite guest users (if `invite_students = true`)

## Quick start
```bash
cd examples/training-sandboxes/infra
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform apply
```

## Middleware (gateway) layer
Installs Envoy Gateway + cert-manager and prepares shared Gateway resources. Routes and certificates are created later by the Helm chart during labs.

```bash
cd examples/training-sandboxes/middleware
cp terraform.tfvars.example terraform.tfvars
./init_backend.sh
terraform apply
```

This layer reads the infra state and upgrades all students by default. Use `target_students` in `middleware/terraform.tfvars` to limit the scope.

## Stardog application layer
Deploys Stardog into an existing sandbox AKS cluster using the shared ACR and the standalone Stardog Helm chart.

```bash
cd examples/training-sandboxes/stardog
cp terraform.tfvars.example terraform.tfvars
./init_backend.sh
terraform apply
```

## Stop all AKS clusters immediately
```bash
cd examples/training-sandboxes/infra
./stop_aks_now.sh
```

## DNS setup (optional)
1) Delegate a sub-zone such as `training.example.com` from the parent zone in your main tenant.
2) Set the following variables:
   - `dns_zone_name = "training.example.com"`
   - `dns_zone_resource_group = "<resource group of the delegated zone>"`
   - `create_student_dns_records = true`

By default only `*.{student}` records are created (for example `*.sd1.training.example.com`).
Enable `create_student_dns_root_record = true` to also create `sd1.training.example.com`.

## Variables
Copy each `terraform.tfvars.example` to `terraform.tfvars`, then edit the files for your subscription/tenant, region, student emails, and backend details.

### Notes
- Invitations create guest user objects immediately; students can accept later.
- The student tfstate container name defaults to `<name_prefix>-tfstate` (hyphens enforced).
