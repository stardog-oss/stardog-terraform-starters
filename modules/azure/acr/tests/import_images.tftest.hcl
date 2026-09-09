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

  # Real bug caught live, twice: Azure's importImage API rejects a *present* credentials object
  # with a null password ("The Password field is required") rather than treating it as "no
  # credentials supplied". Two earlier HCL-only fixes (a merge() with a mismatched-shape ternary,
  # then a same-shape object-or-null ternary) both still produced this live, because HCL's
  # conditional-expression type unification pads null-valued fields across every for_each instance
  # of the resource, not just within one ternary's own branches. The actual fix routes body through
  # jsonencode/jsondecode per-instance (see acr_import_body_json) - asserting strict equality with
  # `null` here is exactly what would have caught both regressions before they ever reached a real
  # apply.
  assert {
    condition     = nonsensitive(azapi_resource_action.acr_import["stardog/stardog:11.2.5"].body).source.credentials == null
    error_message = "no source_registry_username/password configured for a non-jfrog image must mean a fully null credentials value, not a credentials object with null username/password (Azure's importImage API rejects the latter as invalid, not 'anonymous')."
  }
}
