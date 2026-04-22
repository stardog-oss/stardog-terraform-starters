# Training Sandboxes - Stardog

This example deploys the standalone Stardog Helm chart into an existing AKS cluster.

It assumes:
- the AKS cluster already exists
- an ACR already exists and is reachable from the cluster
- the chart and image artifacts are available from the registries you reference

## Quick start
```bash
cp terraform.tfvars.example terraform.tfvars
./init_backend.sh
terraform apply
```

## Main inputs
- `subscription_id`
- `resource_group_name`
- `aks_name`
- `acr_name`
- `ingress_dns_root`
- `stardog_namespace`
- `stardog_release`
- `stardog_chart_url`
- `stardog_chart_version`

## Sensitive inputs
Pass these through environment variables instead of committing them:
- `TF_VAR_jfrog_registry_username`
- `TF_VAR_jfrog_registry_password`
- `TF_VAR_stardog_license_base64`
