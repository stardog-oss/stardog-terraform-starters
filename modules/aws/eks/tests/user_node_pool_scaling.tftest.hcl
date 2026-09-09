# Make the module testable without real AWS credentials
mock_provider "aws" {}

run "only_max_count_set_does_not_borrow_default_pools_min_size" {
  command = plan

  variables {
    cluster_name       = "ut-eks"
    vpc_id             = "vpc-000000"
    private_subnet_ids = ["subnet-a", "subnet-b"]
    aws_region         = "us-west-2"
    # Default node group's own sizing - deliberately different from what a correct per-pool
    # fallback would produce, so a regression (falling back to these again) is caught.
    node_min_size = 3
    node_max_size = 5
    user_node_pools = {
      sdpool = {
        vm_size         = "m5.large"
        os_disk_size_gb = 100
        max_count       = 2
      }
    }
  }

  # Real bug this guards against: min_size used to fall back to var.node_min_size (3, the DEFAULT
  # node group's own setting) whenever a pool left min_count unset - producing min(3) > max(2), an
  # EKS API rejection. min_size must come from pool-local values only.
  assert {
    condition     = local.user_node_pool_min_size["sdpool"] == 1
    error_message = "min_size should default to 1 (pool-local), not borrow the default pool's node_min_size."
  }

  assert {
    condition     = local.user_node_pool_max_size["sdpool"] == 2
    error_message = "max_size should be the explicitly-set max_count."
  }

  assert {
    condition     = local.user_node_pool_min_size["sdpool"] <= local.user_node_pool_max_size["sdpool"]
    error_message = "min_size must never exceed max_size."
  }
}

run "only_min_count_set_produces_consistent_max_and_desired" {
  command = plan

  variables {
    cluster_name       = "ut-eks"
    vpc_id             = "vpc-000000"
    private_subnet_ids = ["subnet-a", "subnet-b"]
    aws_region         = "us-west-2"
    user_node_pools = {
      zkpool = {
        vm_size         = "m5.large"
        os_disk_size_gb = 100
        min_count       = 5
      }
    }
  }

  assert {
    condition     = local.user_node_pool_min_size["zkpool"] == 5
    error_message = "min_size should be the explicitly-set min_count."
  }

  assert {
    condition     = local.user_node_pool_max_size["zkpool"] == 5
    error_message = "max_size should default to min_size when only min_count is set, not an unrelated global default."
  }

  assert {
    condition     = local.user_node_pool_desired_size["zkpool"] >= local.user_node_pool_min_size["zkpool"] && local.user_node_pool_desired_size["zkpool"] <= local.user_node_pool_max_size["zkpool"]
    error_message = "desired_size must always fall within [min_size, max_size]."
  }
}
