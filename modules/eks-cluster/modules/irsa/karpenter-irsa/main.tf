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

data "aws_iam_policy_document" "karpenter" {
  statement {
    actions = [
      "ec2:CreateFleet",
      "ec2:CreateLaunchTemplate",
      "ec2:CreateTags",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeImages",
      "ec2:DescribeImages",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceTypeOfferings",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSpotPriceHistory",
      "ec2:DescribeSubnets",
      "pricing:GetProducts",
    ]

    resources = ["*"]
  }

  statement {
    actions = [
      "ec2:TerminateInstances",
      "ec2:DeleteLaunchTemplate",
    ]

    resources = ["*"]

    condition {
      test     = "ForAllValues:StringEquals"
      variable = "aws:TagKeys"
      values   =  [for cluster_id in var.cluster_ids: "karpenter.sh/discovery/${cluster_id}"]
    }
  }

  statement {
    actions = ["ec2:RunInstances"]
    resources = [
      "arn:${local.partition}:ec2:*:${local.account_id}:launch-template/*",
      "arn:${local.partition}:ec2:*:${local.account_id}:key-pair/*"
    ]

    condition {
      test     = "ForAllValues:StringEquals"
      variable = "aws:TagKeys"
      values   = [for cluster_id in var.cluster_ids: "karpenter.sh/discovery/${cluster_id}"]
    }
  }

  statement {
    actions = ["ec2:RunInstances"]
    resources = [
      "arn:${local.partition}:ec2:*::image/*",
      "arn:${local.partition}:ec2:*:${local.account_id}:instance/*",
      "arn:${local.partition}:ec2:*:${local.account_id}:spot-instances-request/*",
      "arn:${local.partition}:ec2:*:${local.account_id}:security-group/*",
      "arn:${local.partition}:ec2:*:${local.account_id}:volume/*",
      "arn:${local.partition}:ec2:*:${local.account_id}:network-interface/*",
      "arn:${local.partition}:ec2:*:${coalesce(var.subnet_account_id, local.account_id)}:subnet/*",
    ]
  }

  statement {
    actions   = ["ssm:GetParameter"]
    resources = var.ssm_parameter_arns
  }

  statement {
    actions   = ["iam:PassRole"]
    resources = var.node_iam_role_arns
  }

  dynamic "statement" {
    for_each = var.sqs_queue_arn != null ? [1] : []

    content {
      actions = [
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
        "sqs:GetQueueUrl",
        "sqs:ReceiveMessage",
      ]
      resources = [var.karpenter_sqs_queue_arn]
    }
  }
}

resource "aws_iam_policy" "karpenter" {
  name_prefix = "AmazonEKS_Karpenter_Controller_Policy-"
  description = "Provides permissions to karpenter"
  policy      = data.aws_iam_policy_document.karpenter.json

  tags = merge(
    var.common_tags
  )
}

resource "aws_iam_role_policy_attachment" "karpenter" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.karpenter.arn
}