resource "aws_eks_node_group" "this" {
  cluster_name    = var.cluster_name
  node_group_name = var.node_group.node_group_name
  node_role_arn   = var.node_group.node_role_arn
  scaling_config {
    desired_size = var.node_group.scaling_config.desired_size
    max_size     = var.node_group.scaling_config.max_size
    min_size     = var.node_group.scaling_config.min_size
  }
  subnet_ids = var.node_group.subnet_ids

  ami_type       = var.node_group.ami_type
  capacity_type  = var.node_group.capacity_type
  disk_size      = var.node_group.disk_size
  instance_types = var.node_group.instance_types
  labels         = var.node_group.labels
  dynamic "remote_access" {
    for_each = var.node_group.remote_access.ec2_ssh_key == "" ? [] : [0]

    content {
      ec2_ssh_key = var.node_group.remote_access.ec2_ssh_key
    }
  }

  tags = merge(
    var.common_tags,
    {
      ClusterName                                  = var.cluster_name
      Name                                         = var.node_group.node_group_name
    },
  )
}
