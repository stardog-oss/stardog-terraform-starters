# Real bug class this guards against: naive bash string-splitting to tell "explicit registry
# prefix" apart from "bare Docker Hub namespace" (fixed for the Azure ACR module's own import
# script earlier - see azure/acr/import_images.tf) reimplemented here in Terraform now that the
# copy itself is a real provider resource (skopeo2_copy) instead of a shelled-out script.
mock_provider "aws" {
  mock_resource "aws_ecr_repository" {
    defaults = {
      repository_url = "123456789012.dkr.ecr.us-west-2.amazonaws.com/nbn-shared"
    }
  }
}
mock_provider "skopeo2" {}

run "source_image_parsing_distinguishes_registry_prefix_from_namespace" {
  command = apply

  variables {
    repository_name = "nbn-shared"
    import_images    = true
    images_to_import = [
      "stardog/stardog:11.2.5",                                  # bare Docker Hub namespace, no registry prefix
      "stardog-example-helm-chart.jfrog.io/hello-world-app:latest", # explicit registry (has a dot)
      "localhost/myimage:v1",                                    # explicit registry (localhost special-case)
    ]
    source_registry_username = "apikey"
    source_registry_password = "secret-token"
  }

  assert {
    condition     = skopeo2_copy.import["stardog/stardog:11.2.5"].source[0].image == "docker://docker.io/stardog/stardog:11.2.5"
    error_message = "a bare 'namespace/image:tag' with no dot/colon/localhost first segment must be treated as a docker.io namespace, not a registry host."
  }

  assert {
    condition     = skopeo2_copy.import["stardog-example-helm-chart.jfrog.io/hello-world-app:latest"].source[0].image == "docker://stardog-example-helm-chart.jfrog.io/hello-world-app:latest"
    error_message = "a first segment containing a dot must be treated as an explicit registry host, not folded into the image path."
  }

  assert {
    condition     = skopeo2_copy.import["localhost/myimage:v1"].source[0].image == "docker://localhost/myimage:v1"
    error_message = "'localhost' as the first segment must be treated as an explicit registry host."
  }

  assert {
    condition     = skopeo2_copy.import["stardog/stardog:11.2.5"].destination[0].image == "docker://123456789012.dkr.ecr.us-west-2.amazonaws.com/nbn-shared:11.2.5"
    error_message = "destination must be the repository's own registry/repo URL with just the source image's tag appended - this module keeps a single ECR repository per shared-aws instance, images differentiated by tag only (unlike ACR's per-image-path repositories)."
  }

  # Real bug this guards against: source_registry_username/password must only apply to images
  # whose own parsed registry isn't the default docker.io - otherwise a credential meant for one
  # private registry (e.g. JFrog) would also get sent when pulling the plain Docker Hub images
  # alongside it in the same images_to_import list.
  assert {
    condition     = nonsensitive(skopeo2_copy.import["stardog/stardog:11.2.5"].source[0].login_username) == null
    error_message = "a bare docker.io namespace image must not have source_registry_username/password applied - only images with an explicit non-default registry prefix should."
  }

  assert {
    condition     = nonsensitive(skopeo2_copy.import["stardog-example-helm-chart.jfrog.io/hello-world-app:latest"].source[0].login_username) == "apikey"
    error_message = "an image with an explicit non-default registry prefix must have source_registry_username/password applied."
  }
}
