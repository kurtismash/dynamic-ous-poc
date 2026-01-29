locals {
  projects = {
    for file in fileset("${path.module}/data/projects", "*.json") : trimsuffix(file, ".json") => jsondecode(file("${path.module}/data/projects/${file}"))
  }
}
