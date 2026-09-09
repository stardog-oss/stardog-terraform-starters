run "build_args_are_individually_quoted" {
  command = plan

  variables {
    source_dir            = "."
    registry_name         = "myacr"
    registry_login_server = "myacr.azurecr.io"
    image_name            = "myimage"
    dockerfile            = "docker/Dockerfile with space"
    additional_build_args = ["--build-arg", "FOO=bar baz"]
  }

  # Real bug this guards against: tokens used to be joined with bare spaces into one shell string,
  # so a dockerfile path or additional_build_args entry containing a space broke tokenization
  # (wrong -f target, or an arg silently split into two words). Each token must come out
  # independently quoted.
  assert {
    condition     = strcontains(local.build_args_tokens_quoted, "\"docker/Dockerfile with space\"")
    error_message = "dockerfile path containing a space must remain one quoted token."
  }

  assert {
    condition     = strcontains(local.build_args_tokens_quoted, "\"FOO=bar baz\"")
    error_message = "An additional_build_args entry containing a space must remain one quoted token."
  }
}
