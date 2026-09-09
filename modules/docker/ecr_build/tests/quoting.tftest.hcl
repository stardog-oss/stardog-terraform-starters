run "build_args_are_individually_quoted" {
  command = plan

  variables {
    source_dir     = "."
    repository_url = "123456789012.dkr.ecr.us-west-2.amazonaws.com/myrepo"
    aws_region     = "us-west-2"
    dockerfile     = "docker/Dockerfile with space"
    build_args     = ["--build-arg", "FOO=bar baz"]
  }

  # Real bug this guards against: tokens used to be joined with bare spaces into one shell string,
  # so a dockerfile path or build arg containing a space broke tokenization (wrong -f target, or an
  # arg silently split into two words). Each token must come out independently quoted.
  assert {
    condition     = strcontains(local.docker_build_args_quoted, "\"docker/Dockerfile with space\"")
    error_message = "dockerfile path containing a space must remain one quoted token."
  }

  assert {
    condition     = strcontains(local.docker_build_args_quoted, "\"FOO=bar baz\"")
    error_message = "A build_args entry containing a space must remain one quoted token."
  }
}

run "target_platform_defaults_to_null_not_forced_amd64" {
  command = plan

  variables {
    source_dir     = "."
    repository_url = "123456789012.dkr.ecr.us-west-2.amazonaws.com/myrepo"
    aws_region     = "us-west-2"
  }

  assert {
    condition     = local.platform_export == ""
    error_message = "target_platform should default to null (Docker's own default), not force linux/amd64."
  }
}
