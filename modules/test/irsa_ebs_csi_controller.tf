module "ebs_csi_controller_irsa" {
  source = "git::ssh://git@devgit01.corpdev.hkjc.com:7999/cp/modules.git//AWS_CSP.SM_IRSA?ref=RCP-508"

  common_tags   = var.common_tags
  role_name     = "iam-role-${var.cluster_name}-ebs-csi-controller"
  oidc_providers = {
    this = {
      provider_arn               = try(aws_iam_openid_connect_provider.oidc_provider.arn, "")
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
  policy_arns = {0: "arn:${var.aws_partition}:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"}
}
