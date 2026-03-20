# AWS Network (VPC + Subnets)

Creates a VPC, public/private subnets, and optional internet/NAT gateways tailored for EKS deployments.

## Features
- Provisions a VPC with DNS enabled and tagged resources.
- Creates public and private subnets across available AZs.
- Optionally attaches an internet gateway and NAT gateway(s) with route tables.

## Inputs
| Name | Type | Default | Description |
|------|------|---------|-------------|
| `name` | `string` | n/a | Base name used in tags. |
| `cidr_block` | `string` | n/a | VPC CIDR block. |
| `public_subnet_cidrs` | `list(string)` | n/a | CIDRs for public subnets. |
| `private_subnet_cidrs` | `list(string)` | `[]` | CIDRs for private subnets. |
| `create_internet_gateway` | `bool` | `true` | Create and attach an internet gateway. |
| `single_nat_gateway` | `bool` | `true` | Use a single NAT gateway for all private subnets. |
| `create_nat_gateway` | `bool` | `true` | Provision NAT gateway(s) for private subnet egress. |
| `enable_dns_support` | `bool` | `true` | Enable DNS support on the VPC. |
| `enable_dns_hostnames` | `bool` | `true` | Enable DNS hostnames on the VPC. |
| `tags` | `map(string)` | `{}` | Tags applied to all created resources. |

## Outputs
| Name | Description |
|------|-------------|
| `vpc_id` | ID of the created VPC. |
| `public_subnet_ids` | List of public subnet IDs. |
| `private_subnet_ids` | List of private subnet IDs. |
| `public_route_table_id` | Route table ID for public subnets (when created). |
| `nat_gateway_ids` | List of NAT gateway IDs. |

## Example
```hcl
module "network" {
  source               = "../../modules/aws/network"
  name                 = "${var.inst_id}-network"
  cidr_block           = "10.50.0.0/16"
  public_subnet_cidrs  = ["10.50.1.0/24", "10.50.2.0/24"]
  private_subnet_cidrs = ["10.50.11.0/24", "10.50.12.0/24"]
  tags                 = { environment = var.inst_id }
}
```
