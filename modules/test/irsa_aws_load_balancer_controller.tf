data "aws_iam_policy_document" "aws_load_balancer_controller" {
  statement {
    actions = [
      "iam:CreateServiceLinkedRole",
    ]

    resources = ["arn:${var.aws_partition}:iam::${var.aws_account_id}:role/iam-role-${var.cluster_name}-aws-load-balancer-controller"]

    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values   = ["elasticloadbalancing.amazonaws.com"]
    }
  }

  statement {
    actions = [
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeAddresses",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeVpcs",
      "ec2:DescribeVpcPeeringConnections",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeInstances",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeTags",
      "ec2:DescribeCoipPools",
    ]

    resources = ["*"]
  }

  statement {
    actions = [
      "ec2:GetCoipPoolUsage",
    ]

    resources = ["arn:${var.aws_partition}:ec2:*:${var.aws_account_id}:coip-pool/*"]
  }

  statement {
    actions = [
      "acm:ListCertificates",
    ]

    resources = ["*"]
  }

  statement {
    actions = [
      "acm:DescribeCertificate",
    ]

    resources = ["arn:${var.aws_partition}:acm:*:${var.aws_account_id}:certificate/*"]
  }

  statement {
    actions = [
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeListenerCertificates",
      "elasticloadbalancing:DescribeSSLPolicies",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetGroupAttributes",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:DescribeTags",
    ]

    resources = ["*"]
  }

  statement {
    actions = [
      "iam:ListServerCertificates",
    ]

    resources = ["*"]
  }

  statement {
    actions = [
      "iam:GetServerCertificate",
    ]

    resources = ["arn:${var.aws_partition}:iam::${var.aws_account_id}:server-certificate/iam-role-${var.cluster_name}-aws-load-balancer-controller"]
  }

  statement {
    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:CreateSecurityGroup",
    ]

    resources = [
      "arn:${var.aws_partition}:ec2:*:${var.aws_account_id}:security-group/*",
      "arn:${var.aws_partition}:ec2:*:${var.aws_account_id}:vpc/*"
    ]
  }

  statement {
    actions = [
      "ec2:CreateTags",
    ]

    resources = ["arn:${var.aws_partition}:ec2:*:${var.aws_account_id}:security-group/*"]

    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"
      values   = ["CreateSecurityGroup"]
    }

    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    actions = [
      "ec2:CreateTags",
      "ec2:DeleteTags",
    ]

    resources = ["arn:${var.aws_partition}:ec2:*:${var.aws_account_id}:security-group/*"]

    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["true"]
    }

    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:DeleteSecurityGroup",
    ]

    resources = ["arn:${var.aws_partition}:ec2:*:${var.aws_account_id}:security-group/*"]

    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    actions = [
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:CreateTargetGroup",
    ]

    resources = [
      "arn:${var.aws_partition}:elasticloadbalancing:*:${var.aws_account_id}:targetgroup/*/*",
      "arn:${var.aws_partition}:elasticloadbalancing:*:${var.aws_account_id}:loadbalancer/app/*-${var.cluster_name}-*/*",
      "arn:${var.aws_partition}:elasticloadbalancing:*:${var.aws_account_id}:loadbalancer/net/*-${var.cluster_name}-*/*",
    ]

    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    actions = [
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:CreateRule",
      "elasticloadbalancing:DeleteRule",
    ]

    resources = [
      "arn:${var.aws_partition}:elasticloadbalancing:*:${var.aws_account_id}:loadbalancer/app/*-${var.cluster_name}-*/*",
      "arn:${var.aws_partition}:elasticloadbalancing:*:${var.aws_account_id}:loadbalancer/net/*-${var.cluster_name}-*/*",
      "arn:${var.aws_partition}:elasticloadbalancing:*:${var.aws_account_id}:listener/app/*-${var.cluster_name}-*/*",
      "arn:${var.aws_partition}:elasticloadbalancing:*:${var.aws_account_id}:listener/net/*-${var.cluster_name}-*/*",
      "arn:${var.aws_partition}:elasticloadbalancing:*:${var.aws_account_id}:listener-rule/app/*-${var.cluster_name}-*/*",
      "arn:${var.aws_partition}:elasticloadbalancing:*:${var.aws_account_id}:listener-rule/net/*-${var.cluster_name}-*/*",
    ]
  }

  statement {
    actions = [
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags",
    ]

    resources = [
      "arn:${var.aws_partition}:elasticloadbalancing:*:${var.aws_account_id}:targetgroup/*/*",
      "arn:${var.aws_partition}:elasticloadbalancing:*:${var.aws_account_id}:loadbalancer/app/*-${var.cluster_name}-*/*",
      "arn:${var.aws_partition}:elasticloadbalancing:*:${var.aws_account_id}:loadbalancer/net/*-${var.cluster_name}-*/*",
    ]

    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["true"]
    }

    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    actions = [
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:SetIpAddressType",
      "elasticloadbalancing:SetSecurityGroups",
      "elasticloadbalancing:SetSubnets",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:DeleteTargetGroup",
    ]

    resources = [
      "arn:${var.aws_partition}:elasticloadbalancing:*:${var.aws_account_id}:targetgroup/*/*",
      "arn:${var.aws_partition}:elasticloadbalancing:*:${var.aws_account_id}:loadbalancer/app/*-${var.cluster_name}-*/*",
      "arn:${var.aws_partition}:elasticloadbalancing:*:${var.aws_account_id}:loadbalancer/net/*-${var.cluster_name}-*/*",
    ]

    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    actions = [
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets",
    ]

    resources = ["arn:${var.aws_partition}:elasticloadbalancing:*:${var.aws_account_id}:targetgroup/*/*"]
  }

  statement {
    actions = [
      "elasticloadbalancing:SetWebAcl",
    ]

    resources = ["*"]
  }

  statement {
    actions = [
      "elasticloadbalancing:RemoveTags",
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:AddListenerCertificates",
      "elasticloadbalancing:RemoveListenerCertificates",
      "elasticloadbalancing:ModifyRule",
    ]

    resources = [
      "arn:${var.aws_partition}:elasticloadbalancing:*:${var.aws_account_id}:loadbalancer/app/*-${var.cluster_name}-*/*",
      "arn:${var.aws_partition}:elasticloadbalancing:*:${var.aws_account_id}:loadbalancer/net/*-${var.cluster_name}-*/*",
      "arn:${var.aws_partition}:elasticloadbalancing:*:${var.aws_account_id}:listener/app/*-${var.cluster_name}-*/*/*",
      "arn:${var.aws_partition}:elasticloadbalancing:*:${var.aws_account_id}:listener/net/*-${var.cluster_name}-*/*/*",
      "arn:${var.aws_partition}:elasticloadbalancing:*:${var.aws_account_id}:listener-rule/app/*-${var.cluster_name}-*/*/*",
      "arn:${var.aws_partition}:elasticloadbalancing:*:${var.aws_account_id}:listener-rule/net/*-${var.cluster_name}-*/*/*",
    ]
  }
}

resource "aws_iam_policy" "aws_load_balancer_controller" {
  name_prefix = "iam-policy-${var.cluster_name}-aws-load-balancer-controller-"
  description = "Provides permissions to aws-load-balancer-controller"
  policy      = data.aws_iam_policy_document.aws_load_balancer_controller.json

  tags = merge(
    var.common_tags
  )
}

module "aws_load_balancer_controller_irsa" {
  source = "git::ssh://git@devgit01.corpdev.hkjc.com:7999/cp/modules.git//AWS_CSP.SM_IRSA?ref=RCP-508"

  common_tags    = var.common_tags
  role_name      = "iam-role-${var.cluster_name}-aws-load-balancer-controller"
  oidc_providers = {
    this = {
      provider_arn               = try(aws_iam_openid_connect_provider.oidc_provider.arn, "")
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
  policy_arns = {0: aws_iam_policy.aws_load_balancer_controller.arn}
}
