#
# allow_actions
#
resource "aws_organizations_policy" "scp_allow_actions" {
  # md5("lambda:*,s3:*") => ["lambda:*,s3:*"]
  for_each = { for actions_list in distinct([for ou in local.workload_and_environment_ous_enhanced : sort(ou.scp.allow_actions)]) : md5(join(",", actions_list)) => actions_list if length(actions_list) > 0 }

  name        = "AllowActions-${each.key}"
  description = "Restricts the actions principals can perform to ${join(", ", each.value)}"
  type        = "SERVICE_CONTROL_POLICY"
  content     = jsonencode({ "Version" : "2012-10-17", "Statement" : [{ "Effect" : "Allow", "Action" : "*", "Resource" : "*" }] })
}

resource "aws_organizations_policy_attachment" "scp_allow_actions" {
  # "Path/to/Workload/Environment" => md5("lambda:*,s3:*")
  for_each = { for k, ou in local.workload_and_environment_ous_enhanced : k => md5(join(",", sort(ou.scp.allow_actions))) if length(ou.scp.allow_actions) > 0 }

  policy_id = aws_organizations_policy.scp_allow_actions[each.value].id
  target_id = module.ous.by_name_path[each.key].id
}

#
# allow_regions
#
resource "aws_organizations_policy" "scp_allow_regions" {
  # "eu-west-1,eu-west-2" => ["eu-west-1", "eu-west-2"]
  for_each = { for region_list in distinct([for ou in local.workload_and_environment_ous_enhanced : sort(ou.scp.allow_regions)]) : join(",", region_list) => region_list if length(region_list) > 0 }

  name        = "AllowRegions-${each.key}"
  description = "Deny most actions in regions other than ${each.key}"
  type        = "SERVICE_CONTROL_POLICY"
  content     = jsonencode({ "Version" : "2012-10-17", "Statement" : [{ "Effect" : "Allow", "Action" : "*", "Resource" : "*" }] })
}

resource "aws_organizations_policy_attachment" "scp_allow_regions" {
  # "Path/to/Workload/Environment" => "eu-west-1,eu-west-2"
  for_each = { for k, ou in local.workload_and_environment_ous_enhanced : k => join(",", sort(ou.scp.allow_regions)) if length(ou.scp.allow_regions) > 0 }

  policy_id = aws_organizations_policy.scp_allow_regions[each.value].id
  target_id = module.ous.by_name_path[each.key].id
}

#
# custom
#
resource "aws_organizations_policy" "scp_custom" {
  for_each = toset(distinct(flatten([for ou in local.workload_and_environment_ous_enhanced : [for file in try(ou.scp.custom, []) : file]])))

  name        = each.key
  description = "Custom SCP: ${each.key}"
  type        = "SERVICE_CONTROL_POLICY"
  content     = jsonencode(jsondecode(file("${path.module}/data/templates/organizations/scp/${each.value}")))
}

resource "aws_organizations_policy_attachment" "scp_custom" {
  # "Path/to/Workload/Environment -> scp1.json" => { ou_id: "o-r123-1234567", scp: "scp1.json" }
  for_each = { for item in flatten([
    for k, ou in local.workload_and_environment_ous_enhanced : [
      for file in ou.scp.custom : {
        key   = "${k} -> ${file}"
        value = { ou_id : ou.id, scp : file }
      }
    ]
  ]) : item.key => item.value }

  policy_id = aws_organizations_policy.scp_custom[each.value.scp].id
  target_id = each.value.ou_id
}
