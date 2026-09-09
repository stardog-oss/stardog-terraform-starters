variable "source_dir" {
  description = "Path to the Docker build context directory, relative to the root module."
  type        = string
}

variable "dockerfile" {
  description = "Dockerfile path relative to the context directory."
  type        = string
  default     = "Dockerfile"
}

variable "repository_url" {
  description = "Full ECR repository URI (e.g., 123456789012.dkr.ecr.us-east-1.amazonaws.com/my-repo)."
  type        = string
}

variable "aws_region" {
  description = "AWS region for the ECR repository."
  type        = string
}

variable "tag_prefix" {
  description = "Optional prefix to include in the generated image tag."
  type        = string
  default     = null
}

variable "build_args" {
  description = "Additional arguments to pass to docker build (each entry is a separate token)."
  type        = list(string)
  default     = []
}

variable "include_glob" {
  description = "Glob pattern (relative to context dir) to include when computing the content hash."
  type        = string
  default     = "**"
}

variable "extra_triggers" {
  description = "Additional trigger values that should force a rebuild when changed."
  type        = map(string)
  default     = {}
}

variable "environment" {
  description = "Environment variables to pass to the local-exec provisioner."
  type        = map(string)
  default     = {}
}

variable "target_platform" {
  description = "Sets DOCKER_DEFAULT_PLATFORM for the build (e.g., 'linux/amd64'). Leave null to use Docker's default behavior."
  type        = string
  # null, not "linux/amd64" - the default used to silently contradict this variable's own
  # description ("leave null to use Docker's default"), forcing amd64 on every caller who simply
  # omitted this variable expecting Docker's native (host-architecture) behavior instead.
  default = null
}

variable "shell_interpreter" {
  description = "Interpreter tokens for the local-exec provisioner."
  type        = list(string)
  default     = ["/usr/bin/env", "bash", "-c"]
}
