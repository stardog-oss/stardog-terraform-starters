# Make the module testable without real AWS credentials
mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-west-2a", "us-west-2b", "us-west-2c"]
    }
  }
}

run "nat_gateway_pairs_with_correct_subnet_at_ten_plus_subnets" {
  # apply, not plan - subnet/NAT gateway .id attributes are unknown until apply even against a
  # mocked provider; a fully mocked apply is still local-only, no real AWS calls happen.
  command = apply

  variables {
    name       = "ut"
    cidr_block = "10.0.0.0/16"
    public_subnet_cidrs = [
      "10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24", "10.0.4.0/24",
      "10.0.5.0/24", "10.0.6.0/24", "10.0.7.0/24", "10.0.8.0/24", "10.0.9.0/24",
      "10.0.10.0/24",
    ]
    private_subnet_cidrs = [
      "10.0.20.0/24", "10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24", "10.0.24.0/24",
      "10.0.25.0/24", "10.0.26.0/24", "10.0.27.0/24", "10.0.28.0/24", "10.0.29.0/24",
      "10.0.30.0/24",
    ]
    create_nat_gateway = true
    single_nat_gateway = false
  }

  # Real bug this guards against: with >=10 public subnets, values(aws_subnet.public)[count.index]
  # returned entries ordered by lexicographic key sort ("10" before "2"), not numeric index order -
  # silently pairing NAT gateway #2 with the wrong subnet. Direct key lookup must match exactly.
  assert {
    condition     = aws_nat_gateway.this[2].subnet_id == aws_subnet.public["2"].id
    error_message = "NAT gateway index 2 must be paired with public subnet index 2, not a lexicographically-sorted stand-in."
  }

  assert {
    condition     = aws_nat_gateway.this[10].subnet_id == aws_subnet.public["10"].id
    error_message = "NAT gateway index 10 must be paired with public subnet index 10."
  }
}
