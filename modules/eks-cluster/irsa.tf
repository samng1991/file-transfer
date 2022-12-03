module "karpenter_irsa" {
  source = "./modules/irsa/karpenter-irsa"

  common_tags       = var.common_tags
  role_name         = "iam-role-${var.eks.name}-karpenter"
  cluster_ids       = [data.aws_eks_cluster.this.id]
  node_iam_role_arns = [for node_group in var.eks.node_groups : node_group.node_role_arn]
  oidc_providers = {
    this = {
      provider_arn               = try(aws_iam_openid_connect_provider.oidc_provider.arn, "")
      namespace_service_accounts = ["kube-system:karpenter"]
    }
  }
}

module "aws_load_balancer_controller_irsa" {
  source = "./modules/irsa/aws-load-balancer-controller-irsa"

  common_tags       = var.common_tags
  role_name         = "iam-role-${var.eks.name}-aws-load-balancer-controller"
  oidc_providers = {
    this = {
      provider_arn               = try(aws_iam_openid_connect_provider.oidc_provider.arn, "")
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

module "ebs_csi_controller_irsa" {
  source = "./modules/irsa/ebs-csi-controller-irsa"

  common_tags       = var.common_tags
  role_name         = "iam-role-${var.eks.name}-ebs-csi-controller"
  oidc_providers = {
    this = {
      provider_arn               = try(aws_iam_openid_connect_provider.oidc_provider.arn, "")
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

module "fluent_irsa" {
  source = "./modules/irsa/fluent-irsa"

  common_tags       = var.common_tags
  role_name         = "iam-role-${var.eks.name}-fluent"
  oidc_providers = {
    this = {
      provider_arn               = try(aws_iam_openid_connect_provider.oidc_provider.arn, "")
      namespace_service_accounts = ["kube-system:fluent"]
    }
  }
}

module "thanos_irsa" {
  source = "./modules/irsa/thanos-irsa"

  common_tags       = var.common_tags
  role_name         = "iam-role-${var.eks.name}-thanos"
  oidc_providers = {
    this = {
      provider_arn               = try(aws_iam_openid_connect_provider.oidc_provider.arn, "")
      namespace_service_accounts = ["kube-system:thanos"]
    }
  }
}
