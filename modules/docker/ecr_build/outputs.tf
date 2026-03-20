output "image_uri" {
  value = local.image_uri
}

output "image_tag" {
  value = split(":", local.image_uri)[1]
}

output "repository_path" {
  value = local.repository_path
}
