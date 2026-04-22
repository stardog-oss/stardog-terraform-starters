module "acr" {
  source              = "./modules/azure/acr"
  resource_group_name = var.resource_group_name
  manage_acr          = false          # use existing registry only
 
  acr_name            = var.acr_name
 
  import_images    = true
  images_to_import = var.images_to_import
 
  import_charts           = true
  charts_to_import        = var.charts_to_import
  jfrog_registry_username = var.jfrog_registry_username
  jfrog_registry_password = var.jfrog_registry_password
}
