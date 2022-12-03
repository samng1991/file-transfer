variable "common_tags" {
  type = map(string)
}

variable "cluster_name" {
  type = string
}

variable "node_group" {
  type = object({
    node_group_name = string
    node_role_arn   = string
    scaling_config = object({
      desired_size = number
      max_size     = number
      min_size     = number
    })
    subnet_ids = list(string)

    ami_type       = string
    capacity_type  = string
    disk_size      = number
    instance_types = list(string)
    labels         = map(string)
    remote_access  = object({
      ec2_ssh_key  = string
    })
  })
}
