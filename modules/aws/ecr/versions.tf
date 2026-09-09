terraform {
  required_providers {
    # A real Terraform provider for registry-to-registry image copies (vendors the same
    # containers/image/v5 library skopeo itself is built on, rather than shelling out to a skopeo
    # binary). Chosen over abergmeier/skopeo (this repo's own earlier choice) after that provider's
    # only credential mechanism - a REGISTRY_AUTH_FILE env var pointing at a file written by a
    # sibling local_file resource - turned out to be fundamentally incompatible with
    # tofu-controller's runner pod model: local_file only physically writes during an actual apply,
    # but every reconcile after the first spins up a brand-new, empty ephemeral pod, so the very
    # next plan's refresh (which calls skopeo_copy's own read()) fails with "authentication
    # required" - confirmed live. skopeo2_copy instead takes credentials as direct per-resource
    # arguments (source/destination login_username/login_password), computed fresh from
    # data.aws_ecr_authorization_token on every single plan/apply - no file, no env var, no
    # cross-invocation persistence assumption.
    skopeo2 = {
      source = "bsquare-corp/skopeo2"
      # Pinned below 2.0 - resource-level source{}/destination{} blocks (what main.tf uses, to keep
      # per-image conditional credentials - see that resource's own comment) are deprecated in
      # favor of provider-level-only config, planned for removal in the provider's next major
      # version. A provider-level default can't express "only these images get these credentials",
      # so an unpinned upgrade past that removal would silently break this module.
      version = "~> 1.0"
    }
  }
}
