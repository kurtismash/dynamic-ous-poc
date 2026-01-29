#
# Region restrictions
#
locals {
  unique_region_restrictions = distinct([for project in local.projects : sort(project.aws.allowed_regions)])
}

resource "aws_organizations_policy" "scp_restrict_regions" {
  for_each = { for region_list in local.unique_region_restrictions : join(",", region_list) => region_list if length(region_list) > 0 }

  name        = "RestrictRegions-${each.key}"
  description = "Restrict AWS Regions to: ${each.key}"
  type        = "SERVICE_CONTROL_POLICY"
  content     = jsonencode({})
}

resource "aws_organizations_policy_attachment" "scp_restrict_regions_attachment" {
  for_each = { for k, v in local.projects : "${local.projects_parent_ou_string}/${k}" => join(",", sort(v.aws.allowed_regions)) if length(v.aws.allowed_regions) > 0 }

  policy_id = aws_organizations_policy.scp_restrict_regions[each.value].id
  target_id = module.ous.by_name_path[each.key].id
}
