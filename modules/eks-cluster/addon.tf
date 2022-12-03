resource "aws_eks_addon" "vpc_cni" {
  addon_name   = "vpc-cni"
  cluster_name = var.eks.name

  tags = merge(
    var.common_tags,
    {
      ClusterName = var.eks.name
      Name        = "vpc-cni"
    },
  )

  depends_on = [
    aws_eks_cluster.this,
  ]
}

resource "aws_eks_addon" "kube_proxy" {
  addon_name   = "kube-proxy"
  cluster_name = var.eks.name

  tags = merge(
    var.common_tags,
    {
      ClusterName = var.eks.name
      Name        = "kube-proxy"
    },
  )

  depends_on = [
    aws_eks_cluster.this,
  ]
}