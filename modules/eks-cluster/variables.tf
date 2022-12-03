variable "common_tags" {
  type = map(string)
}

variable "is_create_eks_security_group" {
  type    = bool
  default = false
}

variable "is_create_pod_security_group" {
  type    = bool
  default = false
}

variable "awscli_cidr" {
  type    = string
  default = ""
}

variable "spinnaker_cidr" {
  type    = string
  default = ""
}

variable "istiod_egress_cidrs" {
  type    = list(string)
  default = []
}

variable "eks" {
  type = object({
    name     = string
    type     = string
    role_arn = string
    vpc_config = object({
      id                 = string
      security_group_ids = list(string)
      subnet_ids         = list(string)
    })
    enabled_cluster_log_types = list(string)
    kubernetes_network_config = object({
      service_ipv4_cidr = string
    })
    version = string

    node_groups = list(object({
      node_group_name = string
      node_role_arn   = string
      subnet_ids      = set(string)
    }))

    pod_subnet_ids = list(string)
  })
}
