data "aws_iam_policy_document" "karpenter" {
  statement {
    actions = [
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
    ]

    resources = ["*"]
  }

  statement {
    actions = [
      "ec2:CreateFleet",
      "ec2:CreateLaunchTemplate",
      "ec2:CreateTags",
    ]

    resources = [
      "arn:${var.aws_partition}:ec2:${var.aws_region}:${var.aws_account_id}:fleet/*",
      "arn:${var.aws_partition}:ec2:${var.aws_region}:${var.aws_account_id}:instance/*",
    ]
  }

  statement {
    actions = [
      "ec2:TerminateInstances",
      "ec2:DeleteLaunchTemplate",
    ]

    resources = [
      "arn:${var.aws_partition}:ec2:${var.aws_region}:${var.aws_account_id}:instance/*",
      "arn:${var.aws_partition}:ec2:${var.aws_region}:${var.aws_account_id}:launch-template/*"
    ]

    condition {
      test     = "ForAllValues:StringEquals"
      variable = "aws:TagKeys"
      values   = ["karpenter.sh/discovery/${aws_eks_cluster.this.id}"]
    }
  }

  statement {
    actions = ["ec2:RunInstances"]

    resources = [
      "arn:${var.aws_partition}:ec2:${var.aws_region}:${var.aws_account_id}:launch-template/*",
      "arn:${var.aws_partition}:ec2:${var.aws_region}:${var.aws_account_id}:key-pair/*",
    ]

    condition {
      test     = "ForAllValues:StringEquals"
      variable = "aws:TagKeys"
      values   = ["karpenter.sh/discovery/${aws_eks_cluster.this.id}"]
    }
  }

  statement {
    actions = ["ec2:RunInstances"]
    resources = [
      "arn:${var.aws_partition}:ec2:${var.aws_region}::image/*",
      "arn:${var.aws_partition}:ec2:${var.aws_region}:${var.aws_account_id}:instance/*",
      "arn:${var.aws_partition}:ec2:${var.aws_region}:${var.aws_account_id}:spot-instances-request/*",
      "arn:${var.aws_partition}:ec2:${var.aws_region}:${var.aws_account_id}:security-group/*",
      "arn:${var.aws_partition}:ec2:${var.aws_region}:${var.aws_account_id}:volume/*",
      "arn:${var.aws_partition}:ec2:${var.aws_region}:${var.aws_account_id}:network-interface/*",
      "arn:${var.aws_partition}:ec2:${var.aws_region}:${var.aws_account_id}:subnet/*",
    ]
  }

#   statement {
#     actions   = ["ssm:GetParameter"]
#     resources = var.ssm_parameter_arns
#   }

  statement {
    actions   = ["iam:PassRole"]
    resources = [for node_group in var.node_groups : node_group.node_role_arn]
  }

#   dynamic "statement" {
#     for_each = var.sqs_queue_arn != null ? [1] : []

#     content {
#       actions = [
#         "sqs:DeleteMessage",
#         "sqs:GetQueueAttributes",
#         "sqs:GetQueueUrl",
#         "sqs:ReceiveMessage",
#       ]
#       resources = [var.karpenter_sqs_queue_arn]
#     }
#   }
}

resource "aws_iam_policy" "karpenter" {
  name_prefix = "iam-policy-${var.cluster_name}-karpenter-"
  description = "Provides permissions to karpenter"
  policy      = data.aws_iam_policy_document.karpenter.json

  tags = merge(
    var.common_tags
  )
}

module "karpenter_irsa" {
  source = "git::ssh://git@devgit01.corpdev.hkjc.com:7999/cp/modules.git//AWS_CSP.SM_IRSA?ref=RCP-508"

  common_tags        = var.common_tags
  role_name          = "iam-role-${var.cluster_name}-karpenter"
  oidc_providers = {
    this = {
      provider_arn               = try(aws_iam_openid_connect_provider.oidc_provider.arn, "")
      namespace_service_accounts = ["kube-system:karpenter"]
    }
  }
  policy_arns = {0: aws_iam_policy.karpenter.arn}
}
