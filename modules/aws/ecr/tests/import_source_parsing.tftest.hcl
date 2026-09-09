# Real bug class this guards against: naive bash string-splitting to tell "explicit registry
# prefix" apart from "bare Docker Hub namespace" (fixed for the Azure ACR module's own import
# script earlier - see azure/acr/import_images.tf) reimplemented here in Terraform now that the
# copy itself is a real provider resource (skopeo_copy) instead of a shelled-out script.
mock_provider "aws" {
  mock_resource "aws_ecr_repository" {
    defaults = {
      repository_url = "123456789012.dkr.ecr.us-west-2.amazonaws.com/nbn-shared"
    }
  }
}
mock_provider "skopeo" {}
mock_provider "local" {}

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
  }

  assert {
    condition     = skopeo_copy.import["stardog/stardog:11.2.5"].source_image == "docker://docker.io/stardog/stardog:11.2.5"
    error_message = "a bare 'namespace/image:tag' with no dot/colon/localhost first segment must be treated as a docker.io namespace, not a registry host."
  }

  assert {
    condition     = skopeo_copy.import["stardog-example-helm-chart.jfrog.io/hello-world-app:latest"].source_image == "docker://stardog-example-helm-chart.jfrog.io/hello-world-app:latest"
    error_message = "a first segment containing a dot must be treated as an explicit registry host, not folded into the image path."
  }

  assert {
    condition     = skopeo_copy.import["localhost/myimage:v1"].source_image == "docker://localhost/myimage:v1"
    error_message = "'localhost' as the first segment must be treated as an explicit registry host."
  }

  assert {
    condition     = skopeo_copy.import["stardog/stardog:11.2.5"].destination_image == "docker://123456789012.dkr.ecr.us-west-2.amazonaws.com/nbn-shared:11.2.5"
    error_message = "destination must be the repository's own registry/repo URL with just the source image's tag appended - this module keeps a single ECR repository per shared-aws instance, images differentiated by tag only (unlike ACR's per-image-path repositories)."
  }
}
