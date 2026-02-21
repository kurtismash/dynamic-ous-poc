locals {
  workloads_data = {
    for file in fileset("${path.module}/data/workloads", "*.json") : trimsuffix(file, ".json") => merge(
      jsondecode(file("${path.module}/data/workloads/${file}"))
    )
  }
}
