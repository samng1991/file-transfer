data "aws_iam_policy_document" "fluent" {
  statement {
    actions = ["s3:PutObject"]
    resources = [
      "arn:aws:s3:::s3-${var.cluster_name}-alert",
      "arn:aws:s3:::s3-${var.cluster_name}-audit-log",
      "arn:aws:s3:::s3-${var.cluster_name}-container-log",
      "arn:aws:s3:::s3-${var.cluster_name}-metric",
      "arn:aws:s3:::s3-${var.cluster_name}-alert/*",
      "arn:aws:s3:::s3-${var.cluster_name}-audit-log/*",
      "arn:aws:s3:::s3-${var.cluster_name}-container-log/*",
      "arn:aws:s3:::s3-${var.cluster_name}-metric/*",
    ]
  }
}

resource "aws_iam_policy" "fluent" {
  name_prefix = "iam-policy-${var.cluster_name}-fluent-"
  description = "Provides permissions to fluent"
  policy      = data.aws_iam_policy_document.fluent.json

  tags = merge(
    var.common_tags
  )
}

module "fluent_irsa" {
  source = "git::ssh://git@devgit01.corpdev.hkjc.com:7999/cp/modules.git//AWS_CSP.SM_IRSA?ref=RCP-508"

  common_tags   = var.common_tags
  role_name     = "iam-role-${var.cluster_name}-fluent"
  oidc_providers = {
    this = {
      provider_arn               = try(aws_iam_openid_connect_provider.oidc_provider.arn, "")
      namespace_service_accounts = ["logging:fluent-bit-aggregator"]
    }
  }
  policy_arns = {0: "arn:${var.aws_partition}:iam::aws:policy/CloudWatchAgentServerPolicy", 1: aws_iam_policy.fluent.arn}
}
