# Real bug class this guards against: naive bash string-splitting to tell "explicit registry
# prefix" apart from "bare Docker Hub namespace" - previously hand-rolled in a shelled-out `az acr
# import` script, reimplemented here in Terraform now that import is a real azapi_resource_action
# call to ACR's own importImage ARM action.
mock_provider "azurerm" {
  mock_resource "azurerm_container_registry" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/ut-rg/providers/Microsoft.ContainerRegistry/registries/unittestacr"
    }
  }
}
mock_provider "azapi" {}

run "import_body_distinguishes_registry_prefix_from_namespace_and_wires_jfrog_creds" {
  command = apply

  variables {
    resource_group_name = "ut-acr-rg"
    location             = "eastus"
    acr_name             = "unittestacr"
    acr_sku              = "Basic"
    tags                 = { env = "test" }
    cluster              = {}

    import_images    = true
    images_to_import = [
      "stardog/stardog:11.2.5",                                      # bare Docker Hub namespace
      "stardog-example-helm-chart.jfrog.io/hello-world-app:latest",   # explicit jfrog registry
    ]
    jfrog_registry_username = "apikey"
    jfrog_registry_password = "secret-token"
  }

  # The whole `body.source` object is sensitive for every instance (not just the jfrog one) since
  # it's built from a single `for` expression touching both source_registry_password and
  # jfrog_registry_password across all map entries - Terraform can't track sensitivity per-key
  # within that construction, so it conservatively taints the whole map. nonsensitive() is the
  # documented, intended way to unwrap that for assertions on fake test-only credentials.
  assert {
    condition     = nonsensitive(azapi_resource_action.acr_import["stardog/stardog:11.2.5"].body).source.registryUri == "registry.hub.docker.com"
    error_message = "a bare 'namespace/image:tag' with no dot/colon/localhost first segment must resolve to Docker Hub's real importImage host, not be folded in as part of the image path."
  }

  assert {
    condition     = nonsensitive(azapi_resource_action.acr_import["stardog-example-helm-chart.jfrog.io/hello-world-app:latest"].body).source.registryUri == "stardog-example-helm-chart.jfrog.io"
    error_message = "a first segment containing a dot must be treated as an explicit registry host, not folded into the image path."
  }

  assert {
    condition     = nonsensitive(azapi_resource_action.acr_import["stardog-example-helm-chart.jfrog.io/hello-world-app:latest"].body).source.credentials.username == "apikey"
    error_message = "a jfrog.io source registry must use the jfrog_registry_username/password variables, not source_registry_username/password."
  }
}
