locals {
  other_ous = jsondecode(file("${path.module}/data/organization_structure.json"))

  project_ous = {
    for project_name, project_data in local.projects : project_name => {
      for k, v in project_data.aws.environments : k => {}
    }
  }

  # It's a lot easier to do this manually, but it overrides local.other_ous with the same keys
  projects_parent_ou_string = "Managed OUs/Projects"
  projects_parent_ou_map    = { "Managed OUs" = { "Projects" = local.project_ous } }
}

module "ous" {
  source = "github.com/nationalarchives/terraform-aws-organizations-ous-by-path?ref=fix/new-org-deployment"

  organization_id        = "o-1234"
  organization_root_id   = "r-abcdefg"
  organization_structure = merge(local.other_ous, local.projects_parent_ou_map)
}
