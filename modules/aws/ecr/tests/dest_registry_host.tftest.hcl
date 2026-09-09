# Make the module testable without real AWS credentials
mock_provider "aws" {
  mock_resource "aws_ecr_repository" {
    defaults = {
      repository_url = "123456789012.dkr.ecr.us-west-2.amazonaws.com/myrepo"
    }
  }
}

run "dest_registry_host_strips_repository_path" {
  # apply, not plan - repository_url is unknown-until-apply even against a mocked provider unless
  # the plan-phase value is separately overridden; a fully mocked apply is still local-only, no real
  # AWS calls happen.
  command = apply

  variables {
    repository_name = "myrepo"
  }

  # Real bug this guards against: replace() only treats its pattern as a regex when delimited with
  # /.../ - without it, this was a literal substring match that never fired, leaving the full
  # "registry/repo-name" string instead of just the registry host.
  assert {
    condition     = output.dest_registry_host == "123456789012.dkr.ecr.us-west-2.amazonaws.com"
    error_message = "dest_registry_host should strip everything from the first '/' onward."
  }
}
