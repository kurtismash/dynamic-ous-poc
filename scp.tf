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
  content     = jsonencode({ "Version" : "2012-10-17", "Statement" : [{ "Effect" : "Allow", "Action" : "*", "Resource" : "*" }] })
}

resource "aws_organizations_policy_attachment" "scp_restrict_regions_attachment" {
  # "Managed OUs/Projects/Team1-ProjectA/Prod" => "eu-west-1,eu-west-2"
  for_each = { for k, ou in local.ous_with_project_data : k => join(",", sort(ou.controls.allowed_regions)) if try(length(ou.controls.allowed_regions), 0) > 0 }

  policy_id = aws_organizations_policy.scp_restrict_regions[each.value].id
  target_id = module.ous.by_name_path[each.key].id
}

#
# Custom SCPs
#
resource "aws_organizations_policy" "scp_custom" {
  for_each = toset(distinct(flatten([for ou in local.ous_with_project_data : [for file in try(ou.controls.custom_scps, []) : file]])))

  name        = each.key
  description = "Custom SCP: ${each.key}"
  type        = "SERVICE_CONTROL_POLICY"
  content     = jsonencode(jsondecode(file("${path.module}/data/templates/scp/${each.value}")))
}

resource "aws_organizations_policy_attachment" "scp_custom" {
  # "Managed OUs/Projects/Team1-ProjectA/Prod -> scp1.json" => { ou_id: "o-r123-1234567", scp: "scp1.json" }
  for_each = { for item in flatten([
    for k, ou in local.ous_with_project_data : [
      for file in try(ou.controls.custom_scps, []) : {
        key   = "${k} -> ${file}"
        value = { ou_id : ou.id, scp : file }
      }
    ]
  ]) : item.key => item.value }

  policy_id = aws_organizations_policy.scp_custom[each.value.scp].id
  target_id = each.value.ou_id
}
