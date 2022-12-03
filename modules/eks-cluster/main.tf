################################################################################
# EKS
################################################################################
resource "aws_eks_cluster" "this" {
  name     = var.eks.name
  role_arn = var.eks.role_arn
  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = false
    security_group_ids = concat(
      var.eks.vpc_config.security_group_ids,
      [
        data.aws_security_group.this.id
      ]
    )
    subnet_ids = var.eks.vpc_config.subnet_ids
  }

  # https://docs.aws.amazon.com/eks/latest/userguide/control-plane-logs.html
  enabled_cluster_log_types = var.eks.enabled_cluster_log_types
  kubernetes_network_config {
    service_ipv4_cidr = var.eks.kubernetes_network_config.service_ipv4_cidr
    ip_family         = "ipv4"
  }
  tags = merge(
    var.common_tags,
    {
      "alpha.eksctl.io/cluster-oidc-enabled" = "true"
      Name = var.eks.name
    },
  )
  version = var.eks.version

  depends_on = [
    aws_security_group.this
  ]
}

data "aws_eks_cluster" "this" {
  name = var.eks.name

  depends_on = [
    aws_eks_cluster.this
  ]
}

data "aws_eks_cluster_auth" "this" {
  name = var.eks.name

  depends_on = [
    aws_eks_cluster.this
  ]
}


################################################################################
# OIDC
################################################################################
data "tls_certificate" "this" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "oidc_provider" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.this.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer

  tags = merge(
    var.common_tags,
    {
      ClusterName = var.eks.name
    }
  )
}