# AWS Secret Vault

Creates an AWS Secrets Manager secret backed by a customer-managed KMS key (optional) and configures access policies for read/write principals.

## Features
- Optionally provisions a dedicated KMS key with custom admin principals.
- Creates the Secrets Manager secret with recovery window and tagging.
- Generates a default secret resource policy or accepts a custom JSON policy.

## Inputs
| Name | Type | Default | Description |
|------|------|---------|-------------|
| `name` | `string` | n/a | Secrets Manager secret name. |
| `description` | `string` | `null` | Secret description. |
| `create_kms_key` | `bool` | `true` | Create a new KMS key for encryption. |
| `kms_key_arn` | `string` | `null` | Existing KMS key ARN (set `create_kms_key = false`). |
| `kms_key_alias` | `string` | `null` | Alias for the created KMS key. |
| `admin_principal_arns` | `list(string)` | `[]` | Principals with full KMS access (in addition to account root). |
| `read_principal_arns` | `list(string)` | `[]` | Principals granted read access to the secret. |
| `write_principal_arns` | `list(string)` | `[]` | Principals granted write access to the secret. |
| `secret_policy_json` | `string` | `null` | Custom resource policy JSON (overrides read/write lists). |
| `recovery_window_in_days` | `number` | `7` | Secret deletion recovery window. |
| `tags` | `map(string)` | `{}` | Tags for the secret (and KMS key when created). |

## Outputs
| Name | Description |
|------|-------------|
| `secret_arn` | ARN of the created secret. |
| `secret_name` | Name of the secret. |
| `kms_key_arn` | ARN of the effective KMS key. |

## Example
```hcl
module "secret_vault" {
  source                = "../../modules/aws/secretvault"
  name                  = "profile-02/stardog"
  description           = "Stardog integration secrets"
  admin_principal_arns  = [aws_iam_role.terraform_execution.arn]
  read_principal_arns   = [module.eks.node_role_arn]
  write_principal_arns  = [module.eks.cluster_role_arn]
  kms_key_alias         = "stardog-secrets"
  tags                  = { environment = var.inst_id }
}
```
