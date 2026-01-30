locals {
  projects = {
    for file in fileset("${path.module}/data/projects", "*.json") : trimsuffix(file, ".json") => merge(
      jsondecode(file("${path.module}/data/projects/${file}"))
    )
  }
}
