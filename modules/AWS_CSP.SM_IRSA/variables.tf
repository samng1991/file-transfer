variable "common_tags" {
  description = "Tags that should exist in all resources"
  type        = map(string)
  default     = {}
}


################################################################################
# IRSA
################################################################################
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

variable "oidc_providers" {   
  description = "Map of OIDC providers where each provider map should contain the `provider`, `provider_arn`, and `namespace_service_accounts`"
  type        = any
  default     = {}
}

variable "policy_arns" {
  description = "Map of ARN of the role policies"
  type        = map(string)
  default     = {}
}