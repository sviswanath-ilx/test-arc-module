# variable "profile_name" {
#   type        = string
#   description = "Provide profile name for AWS CLI"
#   default     = "sandbox" # Replace with your actual AWS CLI profile name
# }

# variable "aws_region" {
#   description = "Provide region name for AWS"
#   type        = string
#   default     = "us-east-2"
# }

variable "ArcForServerEC2SSMRoleName" {
  default     = "AzureArcForServerSSM"
  description = "The name of the IAM role assigned to the EC2 instance for SSM tasks."
}

variable "ArcForServerSSMInstanceProfileName" {
  default     = "AzureArcForServerSSMInstanceProfile"
  description = "The name of the IAM instance profile attached to the EC2 IAM role used for SSM tasks."
}

variable "ConnectorPrimaryIdentifier" {
  description = "Primary Identifier used for session naming"
  type        = string
  default     = ""
}

variable "EC2SSMIAMRoleAutoAssignment" {
  default = "true"
}

variable "EC2SSMIAMRoleAutoAssignmentSchedule" {
  default = "Enable"
}

variable "EC2SSMIAMRoleAutoAssignmentScheduleInterval" {
  default = "1 day"
}

variable "EC2SSMIAMRolePolicyUpdateAllowed" {
  default = "true"
}

variable "connector_primary_identifier" {
  description = "Primary Identifier used for session naming"
  type        = string
}

variable "oidc_audience" {
  description = "OIDC audience (client ID URI from Azure)"
  type        = string
}

variable "oidc_subject" {
  description = "OIDC subject (Azure app or object ID)"
  type        = string
}

variable "oidc_thumbprint" {
  description = "OIDC thumbprint list for AWS OIDC provider"
  type        = list(string)
}

variable "oidc_url" {
  description = "OIDC URL (must include https:// prefix)"
  type        = string
}

variable "client_id_list" {
  description = "Client ID list for the OIDC provider"
  type        = list(string)
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
}

variable "lambda_code_bucket" {
  description = "The name of the S3 bucket to store Lambda code"
  type        = string
}


