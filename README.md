<!-- BEGIN_TF_DOCS -->
# AWS-EC2-Instance

This is the Terraform Module for using Intelex Standard to onboard AWS EC@ instances into AZURE cloud.

## Working Example

In order to utilize this Terraform Module, you can copy and paste the code below and fill your values where appropriate: These values are in Azure "template.json" file.
The CFT template will get during the AWS connector setup in AZURE.

variable "oidc_client_id" {
  description = "OIDC client ID"
}

variable "oidc_thumbprint" {
  description = "OIDC thumbprint"
}

variable "oidc_url" {
  description = "OIDC provider URL"
}


variable "azure_connector_id" {
  description = "Azure Arc connector ID"
}
