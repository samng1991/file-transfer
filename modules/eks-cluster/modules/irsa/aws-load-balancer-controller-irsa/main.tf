data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

locals {
  account_id          = data.aws_caller_identity.current.account_id
  partition           = data.aws_partition.current.partition
  dns_suffix          = data.aws_partition.current.dns_suffix
}

data "aws_iam_policy_document" "this" {
  dynamic "statement" {
    for_each = var.oidc_providers

    content {
      effect  = "Allow"
      actions = ["sts:AssumeRoleWithWebIdentity"]

      principals {
        type        = "Federated"
        identifiers = [statement.value.provider_arn]
      }

      condition {
        test     = "StringEquals"
        variable = "${replace(statement.value.provider_arn, "/^(.*provider/)/", "")}:sub"
        values   = [for sa in statement.value.namespace_service_accounts : "system:serviceaccount:${sa}"]
      }

      # https://aws.amazon.com/premiumsupport/knowledge-center/eks-troubleshoot-oidc-and-irsa/?nc1=h_ls
      condition {
        test     = "StringEquals"
        variable = "${replace(statement.value.provider_arn, "/^(.*provider/)/", "")}:aud"
        values   = ["sts.amazonaws.com"]
      }

    }
  }
}

resource "aws_iam_role" "this" {
  name        = var.role_name
  description = var.role_description

  assume_role_policy    = data.aws_iam_policy_document.this.json

  tags = merge(
    var.common_tags,
    {
      Name = var.role_name
    }
  )
}

data "aws_iam_policy_document" "aws_load_balancer_controller" {
  statement {
    actions = [
      "iam:CreateServiceLinkedRole",
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values   =  ["elasticloadbalancing.amazonaws.com"]
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
      "ec2:GetCoipPoolUsage",
      "ec2:DescribeCoipPools",
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
      "cognito-idp:DescribeUserPoolClient",
      "acm:ListCertificates",
      "acm:DescribeCertificate",
      "iam:ListServerCertificates",
      "iam:GetServerCertificate",
      "waf-regional:GetWebACL",
      "waf-regional:GetWebACLForResource",
      "waf-regional:AssociateWebACL",
      "waf-regional:DisassociateWebACL",
      "wafv2:GetWebACL",
      "wafv2:GetWebACLForResource",
      "wafv2:AssociateWebACL",
      "wafv2:DisassociateWebACL",
      "shield:GetSubscriptionState",
      "shield:DescribeProtection",
      "shield:CreateProtection",
      "shield:DeleteProtection",
    ]

    resources = ["*"]
  }

  statement {
    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
    ]

    resources = ["*"]
  }

  statement {
    actions = [
      "ec2:CreateSecurityGroup",
    ]

    resources = ["*"]
  }

  statement {
    actions = [
      "ec2:CreateTags",
    ]

    resources = ["arn:aws:ec2:*:*:security-group/*"]

    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"
      values   =  ["CreateSecurityGroup"]
    }

    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   =  ["false"]
    }
  }

  statement {
    actions = [
      "ec2:CreateTags",
      "ec2:DeleteTags",
    ]

    resources = ["arn:aws:ec2:*:*:security-group/*"]

    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   =  ["true"]
    }

    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   =  ["false"]
    }
  }

  statement {
    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:DeleteSecurityGroup",
    ]

    resources = ["*"]

    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   =  ["false"]
    }
  }

  statement {
    actions = [
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:CreateTargetGroup",
    ]

    resources = ["*"]

    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   =  ["false"]
    }
  }

  statement {
    actions = [
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:CreateRule",
      "elasticloadbalancing:DeleteRule",
    ]

    resources = ["*"]
  }

  statement {
    actions = [
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags",
    ]

    resources = [
      "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
      "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
      "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*",
    ]

    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   =  ["true"]
    }

    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   =  ["false"]
    }
  }

  statement {
    actions = [
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags",
    ]

    resources = [
      "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
      "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
      "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
      "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*",
    ]
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

    resources = ["*"]

    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   =  ["false"]
    }
  }

  statement {
    actions = [
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets",
    ]

    resources = ["arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"]
  }

  statement {
    actions = [
      "elasticloadbalancing:SetWebAcl",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:AddListenerCertificates",
      "elasticloadbalancing:RemoveListenerCertificates",
      "elasticloadbalancing:ModifyRule",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "aws_load_balancer_controller" {
  name_prefix = "AmazonEKS_AWS_Load_Balancer_Controller_Policy-"
  description = "Provides permissions to aws-load-balancer-controller"
  policy      = data.aws_iam_policy_document.aws_load_balancer_controller.json

  tags = merge(
    var.common_tags
  )
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
}