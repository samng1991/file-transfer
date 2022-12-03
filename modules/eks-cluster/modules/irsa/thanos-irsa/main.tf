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

data "aws_iam_policy_document" "thanos" {
  statement {
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:PutObject",
    ]

    resources = [
      "arn:aws:s3:::s3-poc-thanos/*",
      "arn:aws:s3:::s3-poc-thanos"
    ]
  }
}

resource "aws_iam_policy" "thanos" {
  name_prefix = "AmazonEKS_Thanos_Policy-"
  description = "Provides permissions to thanos"
  policy      = data.aws_iam_policy_document.thanos.json

  tags = merge(
    var.common_tags
  )
}

resource "aws_iam_role_policy_attachment" "thanos" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.thanos.arn
}