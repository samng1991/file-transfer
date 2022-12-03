output "id" {
  value = data.aws_eks_cluster.this.id
}

output "host" {
  value = data.aws_eks_cluster.this.endpoint
}

output "cluster_ca_certificate" {
  value = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
}

output "token" {
  value = data.aws_eks_cluster_auth.this.token
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider if `enable_irsa = true`"
  value       = try(aws_iam_openid_connect_provider.oidc_provider.arn, "")
}