# Stardog Terraform Lab Stack

Copy or extract this directory under:

```text
stardog-terraform-starters/stacks/stardog-terraform-lab
```

The stack is Terraform-driven:

- `terraform_remote_state` reads the infra and middleware outputs
- `azurerm_key_vault_secret` reads OAuth2 and shared Azure AI secrets
- the Stardog module receives environment-specific settings through `helm_set`
- `terraform.values.yaml` contains only the reusable release shape
- the chart is pulled from the GitHub Pages Helm archive
- images use the Docker registry defaults from the chart

State access:

- the backend writes this lab's state to `sdtraining-tfstate`
- remote state data sources read infra and middleware state from `tfstate`

Required variables:

- `TF_VAR_inst_id`
- `TF_VAR_stardog_chart_version`
- `TF_VAR_stardog_license_base64`

One-time init:

```bash
./init_backend.sh
```

Plan and apply:

```bash
tfp -out tfplan
tfa tfplan
```
