#
# Region restrictions
# (would be similar for service restrictions)
#
resource "aws_organizations_policy" "scp_restrict_regions" {
  # "eu-west-1,eu-west-2" => ["eu-west-1", "eu-west-2"]
  for_each = { for region_list in distinct([for ou in local.ous_with_project_data : sort(lookup(ou.controls, "allowed_regions", []))]) : join(",", region_list) => region_list if length(region_list) > 0 }

  name        = "RestrictRegions-${each.key}"
  description = "Restrict AWS Regions to: ${each.key}"
  type        = "SERVICE_CONTROL_POLICY"
  content     = jsonencode({})
}

resource "aws_organizations_policy_attachment" "scp_restrict_regions_attachment" {
  # "Managed OUs/Projects/Team1-ProjectA/Prod" => "eu-west-1,eu-west-2"
  for_each = { for k, ou in local.ous_with_project_data : k => join(",", sort(ou.controls.allowed_regions)) if try(length(ou.controls.allowed_regions), 0) > 0 }

  policy_id = aws_organizations_policy.scp_restrict_regions[each.value].id
  target_id = module.ous.by_name_path[each.key].id
}
