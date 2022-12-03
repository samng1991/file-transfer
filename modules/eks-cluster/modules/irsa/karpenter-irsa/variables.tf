variable "common_tags" {
  type = map(string)
}

variable "role_name" {
  description = "Name of IAM role"
  type        = string
  default     = null
}

variable "role_description" {
  description = "IAM Role description"
  type        = string
  default     = null
}

variable "cluster_ids" {
  description = "Cluster IDs where the Karpenter controller is provisioned/managing"
  type        = list(string)
  default     = null
}

variable "node_iam_role_arns" {
  description = "List of node IAM role ARNs Karpenter can use to launch nodes"
  type        = list(string)
  default     = null
}

variable "subnet_account_id" {
  description = "Account ID of where the subnets Karpenter will utilize resides. Used when subnets are shared from another account"
  type        = string
  default     = ""
}

variable "ssm_parameter_arns" {
  description = "List of SSM Parameter ARNs that contain AMI IDs launched by Karpenter"
  type        = list(string)
  # https://github.com/aws/karpenter/blob/ed9473a9863ca949b61b9846c8b9f33f35b86dbd/pkg/cloudprovider/aws/ami.go#L105-L123
  default = ["arn:aws:ssm:*:*:parameter/aws/service/*"]
}

variable "sqs_queue_arn" {
  description = "(Optional) ARN of SQS used by Karpenter when native node termination handling is enabled"
  type        = string
  default     = null
}

variable "oidc_providers" {
  description = "Map of OIDC providers where each provider map should contain the `provider`, `provider_arn`, and `namespace_service_accounts`"
  type        = any
  default     = {}
}