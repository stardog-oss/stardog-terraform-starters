locals {
  should_run = var.enabled && length(trimspace(var.storage_class_name)) > 0
}

resource "null_resource" "default_storage_class" {
  count = local.should_run ? 1 : 0

  triggers = {
    desired_sc = var.storage_class_name
    kubeconfig = var.kubeconfig_path
  }

  provisioner "local-exec" {
    interpreter = var.shell_interpreter
    command     = "${path.module}/scripts/set-default-storage-class.sh"
    environment = {
      KUBECONFIG = var.kubeconfig_path
      DESIRED_SC = var.storage_class_name
    }
  }
}
