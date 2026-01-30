locals {
  ou_string_delimiter = "/"
  other_ous           = jsondecode(file("${path.module}/data/organization_structure.json"))

  project_ous = {
    for project_name, project_data in local.projects : project_name => {
      for k, v in project_data.aws.environments : k => {}
    }
  }

  # It's a lot easier to do this manually, but it overrides local.other_ous with the same keys
  projects_parent_ou_string = join(local.ou_string_delimiter, ["Managed OUs", "Projects"])
  projects_parent_ou_map    = { "Managed OUs" = { "Projects" = local.project_ous } }
  projects_ou_depth         = length(split(local.ou_string_delimiter, local.projects_parent_ou_string)) + 1
  environments_ou_depth     = local.projects_ou_depth + 1
}

module "ous" {
  source = "github.com/nationalarchives/terraform-aws-organizations-ous-by-path?ref=fix/new-org-deployment"

  organization_id        = "o-1234"
  organization_root_id   = "r-abcdefg"
  organization_structure = merge(local.other_ous, local.projects_parent_ou_map)
}

# Merge the created OUs with project data (controls) for easier access
locals {
  ous_with_project_data = {
    for k, ou in module.ous.by_name_path : k => merge(
      ou,
      { controls : {} },                                                                                                                                                                                                                                                        # Add empty controls by default, makes it easier to access later
      startswith(k, local.projects_parent_ou_string) && length(split(local.ou_string_delimiter, k)) == local.projects_ou_depth ? { controls : local.projects[ou.name].aws.controls } : null,                                                                                    # Project OU, add project controls
      startswith(k, local.projects_parent_ou_string) && length(split(local.ou_string_delimiter, k)) == local.environments_ou_depth ? { controls : local.projects[split(local.ou_string_delimiter, k)[local.projects_ou_depth - 1]].aws.environments[ou.name].controls } : null, # Environment OU, add environment controls
    )
  }
}

output "ous_with_project_data" {
  value = local.ous_with_project_data
}
