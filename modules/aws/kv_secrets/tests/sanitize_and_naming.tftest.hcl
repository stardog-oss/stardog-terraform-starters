# Make the module testable without real AWS credentials
mock_provider "aws" {}

run "sanitizes_invalid_characters" {
  command = plan

  variables {
    secret_arn = "arn:aws:secretsmanager:us-west-2:123456789012:secret:myapp-AbCdEf"
    secrets = {
      "entry one!@#" = { value = "shh" }
    }
  }

  # Real bug this guards against: replace() only treats its pattern as a regex when delimited with
  # /.../ - without the delimiters it's a literal substring match that never fires, silently
  # skipping sanitization. Space/!/# must become "-"; the allowed characters (letters, digits,
  # / _ + = . @ -) must survive untouched.
  assert {
    condition     = aws_secretsmanager_secret.entry["entry one!@#"].name == "myapp-AbCdEf/entry-one-@-"
    error_message = "Invalid characters in the secret name were not sanitized as expected."
  }
}

run "base_secret_name_derived_from_arn_when_no_prefix_given" {
  command = plan

  variables {
    secret_arn = "arn:aws:secretsmanager:us-west-2:123456789012:secret:myapp-AbCdEf"
    secrets = {
      one = { value = "v1" }
    }
  }

  assert {
    condition     = aws_secretsmanager_secret.entry["one"].name == "myapp-AbCdEf/one"
    error_message = "secret_name_prefix should default to the base secret name parsed from secret_arn."
  }
}
