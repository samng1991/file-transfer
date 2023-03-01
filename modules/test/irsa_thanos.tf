data "aws_iam_policy_document" "thanos" {
  statement {
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:PutObject",
    ]

    resources = [
      "arn:aws:s3:::${var.thanos_s3_bucket_name}/*",
      "arn:aws:s3:::${var.thanos_s3_bucket_name}"
    ]
  }
}

resource "aws_iam_policy" "thanos" {
  name_prefix = "iam-policy-${var.cluster_name}-thanos-"
  description = "Provides permissions to thanos"
  policy      = data.aws_iam_policy_document.thanos.json

  tags = merge(
    var.common_tags
  )
}

module "thanos_irsa" {
  source = "git::ssh://git@devgit01.corpdev.hkjc.com:7999/cp/modules.git//AWS_CSP.SM_IRSA?ref=RCP-508"

  common_tags    = var.common_tags
  role_name      = "iam-role-${var.cluster_name}-thanos"
  oidc_providers = {
    this = {
      provider_arn               = try(aws_iam_openid_connect_provider.oidc_provider.arn, "")
      namespace_service_accounts = ["observability:thanos"]
    }
  }
  policy_arns = {0: aws_iam_policy.thanos.arn}
}
