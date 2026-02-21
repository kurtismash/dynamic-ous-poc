locals {
  ou_string_delimiter = " / "
  other_ous           = jsondecode(file("${path.module}/data/organization_structure.json"))

  # Create a map of maps of workload OUs and their environments to pass into our OU module
  standardised_workload_ous_map = {
    for name, data in local.workloads_data : name => merge(
      {
        # Add tags
        "@tags" : { "IsProject" : true },
        "Vtags" : {
          "AlertSlackChannels" : join(" ", data.communication.alert_slack_channels) # JSON is not supported in tag values
          "AlertsEmailAddresses" : join(" ", data.communication.alertsEmailAddresses)
        }
      },
      {
        # Add nested object for each environment
        for k, v in data.aws.environments : k => {}
      }
    )
  }

  # It's a lot easier to do this manually, but it overrides local.other_ous with the same keys
  standardised_workload_parent_ou_string = join(local.ou_string_delimiter, ["Workloads"])
  standardised_workload_parent_ou_map    = { "Workloads" = local.standardised_workload_ous_map }
  standardised_workload_ou_depth         = length(split(local.ou_string_delimiter, local.standardised_workload_parent_ou_string)) + 1
  environments_ou_depth                  = local.standardised_workload_ou_depth + 1
}

module "ous" {
  source = "github.com/nationalarchives/terraform-aws-organizations-ous-by-path?ref=fix/new-org-deployment"

  include_child_accounts      = true
  include_descendant_accounts = true
  name_path_delimiter         = local.ou_string_delimiter
  organization_id             = "o-1234"
  organization_root_id        = "r-abcdefg"
  organization_structure      = merge(local.other_ous, local.standardised_workload_parent_ou_map)
}


locals {
  # Merge the created OUs with workload JSON data for easier access
  workload_and_environment_ous_enhanced = {
    for k, ou in module.ous.by_name_path : k => merge(
      ou,

      # Add properties for workload OUs
      !(startswith(k, local.standardised_workload_parent_ou_string) && length(split(local.ou_string_delimiter, k)) == local.standardised_workload_ou_depth) ? null : {
        scp                        = merge(local.default_scp_object, local.workloads_data[ou.name].aws.policies.scp)
        expected_monthly_spend_usd = local.workloads_data[ou.name].aws.expected_monthly_spend_usd
      },

      # Add properties for environment OUs
      !(startswith(k, local.standardised_workload_parent_ou_string) && length(split(local.ou_string_delimiter, k)) == local.environments_ou_depth) ? null : {
        scp = merge(local.default_scp_object, local.workloads_data[split(local.ou_string_delimiter, k)[local.standardised_workload_ou_depth - 1]].aws.environments[ou.name].policies.scp)
      },
    ) if startswith(k, join("", [local.standardised_workload_parent_ou_string, local.ou_string_delimiter])) # Only include OUs that are in the workload OU tree
  }
}

output "ous_with_project_data" {
  value = local.workload_and_environment_ous_enhanced
}
